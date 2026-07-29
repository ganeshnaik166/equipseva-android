-- Round 3588: Engineer Preventive-Maintenance Kit / Consumables Usage & Cost Tracker
-- PM-kit consumables usage-vs-standard + cost-per-PM tracker — engineer × region × device model × month × kit type
-- × visits × kits consumed vs standard × variance × cost × cost-per-PM vs target × wastage × usage status × CAPA

-- =============================================================================
-- TABLE 1: pm_consumables_r3588 — per engineer/month PM-consumable usage & cost
-- =============================================================================
create table if not exists public.pm_consumables_r3588 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_code text not null,
  engineer_name text not null,
  region text not null,
  device_model text not null,
  period_month date not null,
  pm_visits int,
  kits_consumed int,
  kits_standard int,
  consumable_variance_pct numeric(6,2),
  consumable_cost_rupees numeric(12,2),
  cost_per_pm_rupees numeric(12,2),
  target_cost_per_pm_rupees numeric(12,2),
  wastage_pct numeric(6,2),
  usage_status text not null check (usage_status in (
    'efficient','on_standard','over_consuming','wastage_risk','stockout_risk'
  )),
  kit_type text not null check (kit_type in (
    'filter','lubricant','calibration','gasket_seal','battery','cleaning'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_consumables_r3588 enable row level security;

create index if not exists idx_pm_consumables_r3588_org on public.pm_consumables_r3588(organization_id);
create index if not exists idx_pm_consumables_r3588_month on public.pm_consumables_r3588(period_month);
create index if not exists idx_pm_consumables_r3588_status on public.pm_consumables_r3588(usage_status);

-- =============================================================================
-- TABLE 2: pm_consumables_capa_actions_r3588 — CAPA & cost-recovery actions
-- =============================================================================
create table if not exists public.pm_consumables_capa_actions_r3588 (
  id uuid primary key default gen_random_uuid(),
  usage_log_id uuid not null references public.pm_consumables_r3588(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'over_consumption','high_wastage','stockout_risk','cost_overrun','standard_deviation','kit_quality_issue'
  )),
  root_cause text not null check (root_cause in (
    'operator_over_use','wrong_kit_selected','defective_consumable','poor_inventory_planning',
    'supplier_quality_issue','no_usage_standard','training_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','revise_usage_standard','change_supplier','tighten_inventory_control',
    'audit_kit_returns','update_pm_checklist','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_consumables_capa_actions_r3588 enable row level security;

create index if not exists idx_pm_consumables_capa_r3588_log on public.pm_consumables_capa_actions_r3588(usage_log_id);
create index if not exists idx_pm_consumables_capa_r3588_status on public.pm_consumables_capa_actions_r3588(capa_status);

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

  -- 16 PM-consumable usage rows
  insert into public.pm_consumables_r3588 (
    organization_id, engineer_name, record_code, region, device_model, period_month,
    pm_visits, kits_consumed, kits_standard, consumable_variance_pct,
    consumable_cost_rupees, cost_per_pm_rupees, target_cost_per_pm_rupees, wastage_pct,
    usage_status, kit_type, notes
  )
  select v_org_id, q.eng, q.rcode, q.reg, q.dmodel, q.pmonth::date,
    q.visits, q.kcons, q.kstd, q.varpct,
    q.ccost, q.cpp, q.tcpp, q.waste,
    q.ust, q.kt, q.nt
  from (values
    ('PMK-BLR-01','Ramesh Iyer','south','GE Vivid S60','2026-07-01',
     18,18,18,0.0,54000.00,3000.00,3000.00,1.2,'on_standard','filter','Ultrasound PM filter kits within usage standard'),
    ('PMK-BLR-02','Ramesh Iyer','south','Philips MX40','2026-07-01',
     14,12,14,-14.3,30000.00,2143.00,2500.00,0.8,'efficient','battery','Telemetry battery kits under standard — efficient'),
    ('PMK-CHN-03','Suresh Kumar','south','Drager V500','2026-06-01',
     20,26,20,30.0,78000.00,3900.00,3000.00,9.5,'over_consuming','gasket_seal','Ventilator gasket/seal kits over-consumed 30%'),
    ('PMK-CHN-04','Suresh Kumar','south','Mindray BeneVision','2026-06-01',
     16,17,16,6.3,40000.00,2500.00,2400.00,4.1,'on_standard','cleaning','Monitor cleaning consumables slightly above standard'),
    ('PMK-DEL-05','Anil Sharma','north','Siemens Cios','2026-07-01',
     10,15,10,50.0,95000.00,9500.00,7000.00,14.0,'wastage_risk','lubricant','C-arm lubricant over-used, high wastage flagged'),
    ('PMK-DEL-06','Anil Sharma','north','GE Optima','2026-07-01',
     12,12,12,0.0,66000.00,5500.00,5500.00,2.0,'on_standard','filter','X-ray filter kits on standard'),
    ('PMK-MUM-07','Priya Nair','west','Nihon Kohden','2026-06-01',
     22,20,22,-9.1,44000.00,2000.00,2200.00,1.0,'efficient','battery','EEG battery kits efficient use'),
    ('PMK-MUM-08','Priya Nair','west','Maquet Servo','2026-06-01',
     9,14,9,55.6,84000.00,9333.00,6500.00,18.0,'wastage_risk','gasket_seal','Ventilator seal kits high wastage — recheck technique'),
    ('PMK-HYD-09','Karthik Rao','south','GE Carescape','2026-07-01',
     15,9,15,-40.0,27000.00,1800.00,3000.00,0.5,'stockout_risk','filter','Filter usage far below standard — possible skipped PM / stockout'),
    ('PMK-HYD-10','Karthik Rao','south','Philips IntelliVue','2026-07-01',
     17,18,17,5.9,51000.00,3000.00,2900.00,3.5,'on_standard','cleaning','Monitor cleaning kits near standard'),
    ('PMK-KOL-11','Debasish Ghosh','east','Drager Fabius','2026-06-01',
     11,16,11,45.5,72000.00,6545.00,5000.00,12.5,'over_consuming','calibration','Anesthesia calibration gas over-consumed'),
    ('PMK-KOL-12','Debasish Ghosh','east','Mindray SV300','2026-06-01',
     13,13,13,0.0,39000.00,3000.00,3000.00,2.2,'on_standard','gasket_seal','Ventilator seal kits on standard'),
    ('PMK-PUN-13','Sneha Patil','west','GE Logiq','2026-07-01',
     19,24,19,26.3,60000.00,3158.00,2600.00,8.0,'over_consuming','cleaning','Ultrasound cleaning wipes over-consumed'),
    ('PMK-PUN-14','Sneha Patil','west','Siemens Acuson','2026-07-01',
     14,8,14,-42.9,22000.00,1571.00,2500.00,0.4,'stockout_risk','filter','Probe filter usage well below standard — stockout risk'),
    ('PMK-JAI-15','Vikram Singh','north','Philips Efficia','2026-06-01',
     16,21,16,31.3,68000.00,4250.00,3400.00,11.0,'wastage_risk','lubricant','Defib lubricant/consumable high wastage'),
    ('PMK-JAI-16','Vikram Singh','north','GE MAC','2026-06-01',
     20,20,20,0.0,40000.00,2000.00,2000.00,1.5,'on_standard','battery','ECG battery kits on standard')
  ) as q(rcode, eng, reg, dmodel, pmonth, visits, kcons, kstd, varpct, ccost, cpp, tcpp, waste, ust, kt, nt);

  -- CAPA seed — attach to specific records via record_code
  insert into public.pm_consumables_capa_actions_r3588 (
    usage_log_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.cimp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PMK-CHN-03','over_consumption','operator_over_use','retrain_engineer','in_progress',22000.00,'Suresh Kumar','2026-07-20',null,'Gasket kit over-use — technique retraining scheduled'),
    ('PMK-DEL-05','high_wastage','wrong_kit_selected','revise_usage_standard','open',34000.00,'Anil Sharma','2026-07-25',null,'C-arm lubricant over-application; revise usage standard'),
    ('PMK-MUM-08','high_wastage','training_gap','retrain_engineer','escalated',41000.00,'Priya Nair','2026-07-18',null,'Ventilator seal wastage escalated to regional lead'),
    ('PMK-HYD-09','stockout_risk','poor_inventory_planning','tighten_inventory_control','open',12000.00,'Karthik Rao','2026-07-22',null,'Filter usage below standard — verify PM not skipped, restock'),
    ('PMK-KOL-11','cost_overrun','defective_consumable','change_supplier','verification_pending',18000.00,'Debasish Ghosh','2026-07-15',null,'Calibration gas over-consumption; supplier quality review'),
    ('PMK-PUN-13','over_consumption','no_usage_standard','revise_usage_standard','closed',9000.00,'Sneha Patil','2026-07-10','2026-07-08','Cleaning wipe usage standard defined and rolled out'),
    ('PMK-PUN-14','stockout_risk','poor_inventory_planning','audit_kit_returns','overdue',7000.00,'Sneha Patil','2026-07-05',null,'Probe filter stockout risk — kit return audit overdue'),
    ('PMK-JAI-15','high_wastage','supplier_quality_issue','change_supplier','in_progress',26000.00,'Vikram Singh','2026-07-24',null,'Defib consumable wastage — supplier quality issue')
  ) as q(rcode, fc, rc, ca, cst, cimp, ownr, tcd, acd, nt)
  join public.pm_consumables_r3588 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Usage-status distribution
create or replace function public.founder_r3588_usage_status_rollup()
returns table(usage_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_consumables_r3588)
  select l.usage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pm_consumables_r3588 l
  group by l.usage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3588_usage_status_rollup() from public, anon;
grant execute on function public.founder_r3588_usage_status_rollup() to authenticated;

-- 2) Region scorecard
create or replace function public.founder_r3588_region_scorecard()
returns table(
  region text,
  total_records bigint,
  efficient bigint,
  over_consuming bigint,
  wastage_risk bigint,
  stockout_risk bigint,
  avg_variance_pct numeric,
  avg_cost_per_pm numeric,
  efficient_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.usage_status = 'efficient')::bigint,
    count(*) filter (where l.usage_status = 'over_consuming')::bigint,
    count(*) filter (where l.usage_status = 'wastage_risk')::bigint,
    count(*) filter (where l.usage_status = 'stockout_risk')::bigint,
    round(avg(l.consumable_variance_pct), 2),
    round(avg(l.cost_per_pm_rupees), 0),
    round(100.0 * count(*) filter (where l.usage_status in ('efficient','on_standard'))::numeric / nullif(count(*),0), 1)
  from public.pm_consumables_r3588 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3588_region_scorecard() from public, anon;
grant execute on function public.founder_r3588_region_scorecard() to authenticated;

-- 3) Kit-type × usage-status matrix
create or replace function public.founder_r3588_kit_type_status_matrix()
returns table(kit_type text, usage_status text, records bigint, avg_variance_pct numeric, avg_wastage_pct numeric, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.kit_type, l.usage_status, count(*)::bigint,
    round(avg(l.consumable_variance_pct), 2),
    round(avg(l.wastage_pct), 2),
    coalesce(sum(l.consumable_cost_rupees),0)::numeric
  from public.pm_consumables_r3588 l
  group by l.kit_type, l.usage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3588_kit_type_status_matrix() from public, anon;
grant execute on function public.founder_r3588_kit_type_status_matrix() to authenticated;

-- 4) Monthly consumable-cost trend
create or replace function public.founder_r3588_monthly_cost_trend()
returns table(period_month date, records bigint, total_pm_visits bigint, total_cost_rupees numeric, avg_cost_per_pm numeric, avg_wastage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.pm_visits),0)::bigint,
    coalesce(sum(l.consumable_cost_rupees),0)::numeric,
    round(avg(l.cost_per_pm_rupees), 0),
    round(avg(l.wastage_pct), 2)
  from public.pm_consumables_r3588 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3588_monthly_cost_trend() from public, anon;
grant execute on function public.founder_r3588_monthly_cost_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3588_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.pm_consumables_capa_actions_r3588 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3588_capa_status_board() from public, anon;
grant execute on function public.founder_r3588_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3588_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_consumables_capa_actions_r3588)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pm_consumables_capa_actions_r3588 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3588_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3588_root_cause_pareto() to authenticated;

-- 7) Cost-impact digest by finding category
create or replace function public.founder_r3588_cost_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_cost_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric
  from public.pm_consumables_capa_actions_r3588 c
  group by c.finding_category
  order by coalesce(sum(c.cost_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3588_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3588_cost_impact_digest() to authenticated;

-- 8) High-risk usage queue (over-consuming / wastage / stockout)
create or replace function public.founder_r3588_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  device_model text,
  period_month date,
  kit_type text,
  usage_status text,
  consumable_variance_pct numeric,
  wastage_pct numeric,
  cost_per_pm_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.device_model, l.period_month, l.kit_type,
    l.usage_status, l.consumable_variance_pct, l.wastage_pct, l.cost_per_pm_rupees, l.notes
  from public.pm_consumables_r3588 l
  where l.usage_status in ('over_consuming','wastage_risk','stockout_risk')
     or l.cost_per_pm_rupees > l.target_cost_per_pm_rupees
     or l.wastage_pct >= 8.0
  order by l.wastage_pct desc, l.consumable_variance_pct desc;
end;
$$;

revoke execute on function public.founder_r3588_high_risk_queue() from public, anon;
grant execute on function public.founder_r3588_high_risk_queue() to authenticated;
