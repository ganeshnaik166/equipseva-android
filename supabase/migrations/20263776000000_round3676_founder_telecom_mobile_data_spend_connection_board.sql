-- Round 3676: Founder Telecom / Mobile / Data Spend & Connection Board
-- Telecom admin ops — plan group × carrier × connection type × active/idle connections × monthly spend × overage × roaming × plan-optimal % × disputes × CAPA

-- =============================================================================
-- TABLE 1: telecom_spend_r3676 — per-plan-group telecom/mobile/data spend records
-- =============================================================================
create table if not exists public.telecom_spend_r3676 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_group text not null,
  carrier text not null,
  period_month date not null,
  connections_active int not null default 0,
  connections_idle int not null default 0,
  monthly_spend_rupees numeric(12,2) not null default 0,
  cost_per_connection_rupees numeric(10,2),
  data_overage_charges_rupees numeric(12,2) not null default 0,
  roaming_charges_rupees numeric(12,2) not null default 0,
  plan_optimal_pct numeric(5,1),
  disputes_open int not null default 0,
  connection_type text not null check (connection_type in (
    'field_engineer_sim','office_mobile','data_card','iot_sim','broadband'
  )),
  spend_status text not null check (spend_status in (
    'optimized','on_target','overage_heavy','idle_connections','uncontrolled'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.telecom_spend_r3676 enable row level security;

create index if not exists idx_telecom_spend_r3676_org on public.telecom_spend_r3676(organization_id);
create index if not exists idx_telecom_spend_r3676_month on public.telecom_spend_r3676(period_month);
create index if not exists idx_telecom_spend_r3676_status on public.telecom_spend_r3676(spend_status);

-- =============================================================================
-- TABLE 2: telecom_spend_capa_actions_r3676 — CAPA & cost-recovery actions
-- =============================================================================
create table if not exists public.telecom_spend_capa_actions_r3676 (
  id uuid primary key default gen_random_uuid(),
  spend_record_id uuid not null references public.telecom_spend_r3676(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'idle_connections_not_surrendered','plan_mismatch_high_usage','roaming_pack_not_activated',
    'duplicate_connections','carrier_billing_error','no_usage_governance',
    'legacy_plan_not_migrated','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'surrender_idle_connections','migrate_to_pooled_plan','activate_roaming_pack',
    'deduplicate_connections','raise_carrier_dispute','implement_usage_policy',
    'renegotiate_carrier_contract','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  monthly_waste_rupees numeric(12,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.telecom_spend_capa_actions_r3676 enable row level security;

create index if not exists idx_telecom_spend_capa_r3676_rec on public.telecom_spend_capa_actions_r3676(spend_record_id);
create index if not exists idx_telecom_spend_capa_r3676_status on public.telecom_spend_capa_actions_r3676(capa_status);

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

  -- 16 telecom spend rows
  insert into public.telecom_spend_r3676 (
    organization_id, plan_group, carrier, period_month,
    connections_active, connections_idle, monthly_spend_rupees, cost_per_connection_rupees,
    data_overage_charges_rupees, roaming_charges_rupees, plan_optimal_pct, disputes_open,
    connection_type, spend_status, trend_dir, notes
  )
  select v_org_id, q.pgrp, q.carr, q.pmon::date,
    q.cact, q.cidl, q.spend, q.cpc,
    q.ovg, q.roam, q.popt, q.disp,
    q.ctype, q.sstat, q.tdir, q.nt
  from (values
    ('FE-SIM-MUM-A','Airtel','2026-07-01',
     42,3,52500.00,1250.00,1800.00,950.00,88.5,0,'field_engineer_sim','on_target','stable','Mumbai HQ field engineer SIM pool — minor overage on two lines'),
    ('FE-SIM-CHN-A','Jio','2026-07-01',
     36,1,39600.00,1100.00,0.00,420.00,93.2,0,'field_engineer_sim','optimized','improving','Chennai branch engineer SIMs migrated to pooled data plan'),
    ('OFF-MOB-MUM-EXEC','Airtel','2026-07-01',
     18,0,32400.00,1800.00,5600.00,4200.00,71.4,1,'office_mobile','overage_heavy','worsening','Mumbai HQ exec mobiles — international roaming used without packs'),
    ('DATA-CARD-DEL-WH','Vi','2026-07-01',
     12,5,15300.00,900.00,2100.00,0.00,58.8,1,'data_card','idle_connections','worsening','Delhi warehouse data cards — 5 idle since scanner Wi-Fi upgrade'),
    ('IOT-SIM-COLDCHAIN','Airtel','2026-07-01',
     85,4,21250.00,250.00,0.00,0.00,91.0,0,'iot_sim','optimized','stable','Cold-chain logger IoT SIMs on pooled 50MB plan'),
    ('BB-MUM-HQ','Jio','2026-07-01',
     2,0,11800.00,5900.00,0.00,0.00,95.0,0,'broadband','optimized','stable','Mumbai HQ leased line plus backup broadband'),
    ('BB-CHN-BR','Airtel','2026-07-01',
     1,0,4500.00,4500.00,0.00,0.00,90.0,0,'broadband','on_target','stable','Chennai branch broadband renewed at same tariff'),
    ('OFF-MOB-BLR-SVC','Jio','2026-07-01',
     22,2,28600.00,1300.00,3400.00,600.00,66.7,2,'office_mobile','overage_heavy','stable','Bengaluru service hub mobiles — recurring data overage on CUG plan'),
    ('DATA-CARD-FE-SOUTH','Jio','2026-06-01',
     28,9,33600.00,1200.00,4800.00,0.00,52.5,1,'data_card','uncontrolled','worsening','South zone engineer data cards — no usage governance, 9 idle'),
    ('FE-SIM-DEL-A','Vi','2026-06-01',
     31,6,40300.00,1300.00,2600.00,1100.00,64.0,2,'field_engineer_sim','idle_connections','stable','Delhi warehouse engineer SIMs — leaver SIMs not surrendered'),
    ('IOT-SIM-VENT-FLEET','Jio','2026-06-01',
     120,0,30000.00,250.00,0.00,0.00,96.5,0,'iot_sim','optimized','improving','Ventilator telemetry IoT SIM fleet fully pooled'),
    ('OFF-MOB-HYD-BR','Airtel','2026-06-01',
     15,1,21000.00,1400.00,1500.00,800.00,73.3,0,'office_mobile','on_target','improving','Hyderabad branch mobiles moved to corporate CUG'),
    ('BB-DEL-WH','BSNL','2026-06-01',
     1,0,3800.00,3800.00,0.00,0.00,82.0,1,'broadband','on_target','stable','Delhi warehouse BSNL broadband — one billing dispute open'),
    ('DATA-CARD-PUN-OFF','Vi','2026-05-01',
     9,4,10800.00,1200.00,900.00,0.00,55.6,0,'data_card','idle_connections','worsening','Pune office data cards idle after hybrid-work policy'),
    ('FE-SIM-KOL-A','Airtel','2026-05-01',
     24,2,31200.00,1300.00,5200.00,1900.00,62.5,1,'field_engineer_sim','overage_heavy','worsening','Kolkata engineer SIMs — heavy video diagnostics uploads'),
    ('OFF-MOB-LEGACY-POOL','Vi','2026-05-01',
     11,7,26400.00,2400.00,0.00,0.00,38.9,2,'office_mobile','uncontrolled','worsening','Legacy postpaid pool never migrated — duplicate and idle lines')
  ) as q(pgrp, carr, pmon, cact, cidl, spend, cpc, ovg, roam, popt, disp, ctype, sstat, tdir, nt);

  -- CAPA seed — attach to specific spend records via plan_group
  insert into public.telecom_spend_capa_actions_r3676 (
    spend_record_id, root_cause, corrective_action, capa_status,
    monthly_waste_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.waste, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('OFF-MOB-MUM-EXEC','roaming_pack_not_activated','activate_roaming_pack','in_progress',4200.00,'Admin Manager — Mumbai HQ','2026-08-20',null,'International roaming packs mandated before travel; approval workflow live'),
    ('DATA-CARD-DEL-WH','idle_connections_not_surrendered','surrender_idle_connections','open',4500.00,'Facilities Lead — Delhi Warehouse','2026-08-25',null,'5 idle Vi data cards listed for surrender after Wi-Fi upgrade'),
    ('DATA-CARD-FE-SOUTH','no_usage_governance','implement_usage_policy','escalated',9600.00,'IT Admin — Bengaluru Service Hub','2026-08-15',null,'Uncontrolled data-card usage escalated to COO; fair-usage policy drafted'),
    ('FE-SIM-DEL-A','idle_connections_not_surrendered','surrender_idle_connections','verification_pending',7800.00,'HR Ops — Delhi Warehouse','2026-08-10',null,'Leaver SIM surrender linked to exit checklist — verifying with Vi'),
    ('OFF-MOB-BLR-SVC','plan_mismatch_high_usage','migrate_to_pooled_plan','in_progress',3400.00,'Admin Executive — Bengaluru','2026-08-18',null,'CUG plan upgrade to pooled 100GB under negotiation with Jio'),
    ('BB-DEL-WH','carrier_billing_error','raise_carrier_dispute','closed',1200.00,'Accounts Payable — Mumbai HQ','2026-07-30','2026-07-22','BSNL double-billed static IP; credit note received'),
    ('OFF-MOB-LEGACY-POOL','legacy_plan_not_migrated','renegotiate_carrier_contract','overdue',14200.00,'Procurement Head — Mumbai HQ','2026-07-31',null,'Legacy Vi postpaid pool renegotiation slipped past target date'),
    ('FE-SIM-KOL-A','plan_mismatch_high_usage','migrate_to_pooled_plan','open',5200.00,'Admin Manager — Kolkata Branch','2026-08-28',null,'Video-diagnostics upload load needs higher-data pooled plan')
  ) as q(pgrp, rc, ca, cst, waste, ownr, tcd, acd, nt)
  join public.telecom_spend_r3676 e
    on e.organization_id = v_org_id and e.plan_group = q.pgrp;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend status distribution
create or replace function public.founder_r3676_spend_status_rollup()
returns table(spend_status text, records bigint, total_spend_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.telecom_spend_r3676)
  select l.spend_status, count(*)::bigint,
         coalesce(sum(l.monthly_spend_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.telecom_spend_r3676 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3676_spend_status_rollup() from public, anon;
grant execute on function public.founder_r3676_spend_status_rollup() to authenticated;

-- 2) Carrier scorecard
create or replace function public.founder_r3676_carrier_scorecard()
returns table(
  carrier text,
  plan_groups bigint,
  active_connections bigint,
  idle_connections bigint,
  total_spend_rupees numeric,
  overage_rupees numeric,
  roaming_rupees numeric,
  disputes bigint,
  avg_plan_optimal_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.carrier,
    count(*)::bigint,
    coalesce(sum(l.connections_active),0)::bigint,
    coalesce(sum(l.connections_idle),0)::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    coalesce(sum(l.data_overage_charges_rupees),0)::numeric,
    coalesce(sum(l.roaming_charges_rupees),0)::numeric,
    coalesce(sum(l.disputes_open),0)::bigint,
    round(avg(l.plan_optimal_pct), 1)
  from public.telecom_spend_r3676 l
  group by l.carrier
  order by coalesce(sum(l.monthly_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3676_carrier_scorecard() from public, anon;
grant execute on function public.founder_r3676_carrier_scorecard() to authenticated;

-- 3) Connection type × spend status matrix
create or replace function public.founder_r3676_conn_type_status_matrix()
returns table(connection_type text, spend_status text, records bigint, total_spend_rupees numeric, idle_connections bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.connection_type, l.spend_status, count(*)::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    coalesce(sum(l.connections_idle),0)::bigint
  from public.telecom_spend_r3676 l
  group by l.connection_type, l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3676_conn_type_status_matrix() from public, anon;
grant execute on function public.founder_r3676_conn_type_status_matrix() to authenticated;

-- 4) Monthly spend trend
create or replace function public.founder_r3676_monthly_spend_trend()
returns table(period_month date, records bigint, total_spend_rupees numeric, overage_rupees numeric, roaming_rupees numeric, avg_plan_optimal_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    coalesce(sum(l.data_overage_charges_rupees),0)::numeric,
    coalesce(sum(l.roaming_charges_rupees),0)::numeric,
    round(avg(l.plan_optimal_pct), 1)
  from public.telecom_spend_r3676 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3676_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3676_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3676_capa_status_board()
returns table(capa_status text, actions bigint, avg_waste_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.monthly_waste_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.telecom_spend_capa_actions_r3676 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3676_capa_status_board() from public, anon;
grant execute on function public.founder_r3676_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3676_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_waste_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.telecom_spend_capa_actions_r3676)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.monthly_waste_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.telecom_spend_capa_actions_r3676 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3676_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3676_root_cause_pareto() to authenticated;

-- 7) Overage / idle waste digest
create or replace function public.founder_r3676_overage_idle_digest()
returns table(connection_type text, records bigint, overage_rupees numeric, roaming_rupees numeric, idle_connections bigint, idle_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.connection_type,
    count(*)::bigint,
    coalesce(sum(l.data_overage_charges_rupees),0)::numeric,
    coalesce(sum(l.roaming_charges_rupees),0)::numeric,
    coalesce(sum(l.connections_idle),0)::bigint,
    round(100.0 * coalesce(sum(l.connections_idle),0)::numeric
      / nullif(coalesce(sum(l.connections_active),0) + coalesce(sum(l.connections_idle),0), 0), 1)
  from public.telecom_spend_r3676 l
  group by l.connection_type
  order by coalesce(sum(l.data_overage_charges_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3676_overage_idle_digest() from public, anon;
grant execute on function public.founder_r3676_overage_idle_digest() to authenticated;

-- 8) High-risk queue (uncontrolled / idle-heavy plan groups)
create or replace function public.founder_r3676_high_risk_queue()
returns table(
  plan_group text,
  carrier text,
  period_month date,
  connection_type text,
  spend_status text,
  trend_dir text,
  connections_idle int,
  data_overage_charges_rupees numeric,
  disputes_open int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.plan_group, l.carrier, l.period_month, l.connection_type,
    l.spend_status, l.trend_dir, l.connections_idle,
    l.data_overage_charges_rupees, l.disputes_open, l.notes
  from public.telecom_spend_r3676 l
  where l.spend_status in ('uncontrolled','idle_connections','overage_heavy')
     or l.trend_dir = 'worsening'
     or l.disputes_open > 0
  order by l.period_month desc, l.plan_group;
end;
$$;

revoke all on function public.founder_r3676_high_risk_queue() from public, anon;
grant execute on function public.founder_r3676_high_risk_queue() to authenticated;
