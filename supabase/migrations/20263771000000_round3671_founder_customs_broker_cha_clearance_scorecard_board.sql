-- Round 3671: Founder Customs-Broker (CHA) Clearance Scorecard Board
-- CHA performance — broker × port × period × shipments × clearance days vs target × first-time clearance × query rate × penalties × brokerage spend × doc errors × CAPA

-- =============================================================================
-- TABLE 1: cha_scorecard_r3671 — per-broker / per-port monthly clearance scorecard
-- =============================================================================
create table if not exists public.cha_scorecard_r3671 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  scorecard_code text not null,
  broker_name text not null,
  port_name text not null,
  period_month date not null,
  shipments_handled int not null,
  avg_clearance_days numeric(6,2) not null,
  target_clearance_days numeric(6,2) not null,
  first_time_clearance_pct numeric(5,2),
  query_rate_pct numeric(5,2),
  penalty_incidents int not null default 0,
  brokerage_spend_rupees numeric(12,2),
  doc_error_rate_pct numeric(5,2),
  shipment_mode text not null check (shipment_mode in (
    'air_import','sea_import','air_export','sea_export','courier_bill'
  )),
  performance_status text not null check (performance_status in (
    'excellent','on_target','slipping','poor','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cha_scorecard_r3671 enable row level security;

create index if not exists idx_cha_scorecard_r3671_org on public.cha_scorecard_r3671(organization_id);
create index if not exists idx_cha_scorecard_r3671_month on public.cha_scorecard_r3671(period_month);
create index if not exists idx_cha_scorecard_r3671_status on public.cha_scorecard_r3671(performance_status);

-- =============================================================================
-- TABLE 2: cha_scorecard_capa_actions_r3671 — CAPA & broker-improvement actions
-- =============================================================================
create table if not exists public.cha_scorecard_capa_actions_r3671 (
  id uuid primary key default gen_random_uuid(),
  scorecard_id uuid not null references public.cha_scorecard_r3671(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'clearance_delay','high_query_rate','documentation_errors','penalty_incident',
    'brokerage_overbilling','first_time_clearance_drop','duty_misclassification','shipment_hold'
  )),
  root_cause text not null check (root_cause in (
    'incomplete_import_docs','hs_code_misclassification','broker_staff_shortage',
    'customs_system_downtime','late_checklist_submission','duty_payment_delay',
    'port_congestion','pending_investigation','sops_not_followed'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_broker_team','switch_backup_broker','implement_doc_checklist',
    'pre_file_bill_of_entry','escalate_to_broker_management','renegotiate_brokerage_sla',
    'automate_doc_validation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  demurrage_cost_rupees numeric(12,2),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cha_scorecard_capa_actions_r3671 enable row level security;

create index if not exists idx_cha_scorecard_capa_r3671_log on public.cha_scorecard_capa_actions_r3671(scorecard_id);
create index if not exists idx_cha_scorecard_capa_r3671_status on public.cha_scorecard_capa_actions_r3671(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Performance status distribution
create or replace function public.founder_r3671_performance_status_rollup()
returns table(performance_status text, scorecards bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cha_scorecard_r3671)
  select l.performance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cha_scorecard_r3671 l
  group by l.performance_status
  order by count(*) desc;
end;
$$;

-- 2) Broker-level clearance scorecard
create or replace function public.founder_r3671_broker_scorecard()
returns table(
  broker_name text,
  scorecards bigint,
  shipments bigint,
  avg_clearance_days numeric,
  avg_first_time_pct numeric,
  avg_query_rate_pct numeric,
  penalty_incidents bigint,
  total_spend_rupees numeric,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.broker_name,
    count(*)::bigint,
    coalesce(sum(l.shipments_handled),0)::bigint,
    round(avg(l.avg_clearance_days), 2),
    round(avg(l.first_time_clearance_pct), 1),
    round(avg(l.query_rate_pct), 1),
    coalesce(sum(l.penalty_incidents),0)::bigint,
    coalesce(sum(l.brokerage_spend_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.performance_status in ('excellent','on_target'))::numeric / nullif(count(*),0), 1)
  from public.cha_scorecard_r3671 l
  group by l.broker_name
  order by count(*) desc;
end;
$$;

-- 3) Shipment mode × performance status matrix
create or replace function public.founder_r3671_mode_status_matrix()
returns table(shipment_mode text, performance_status text, scorecards bigint, shipments bigint, avg_clearance_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shipment_mode, l.performance_status, count(*)::bigint,
    coalesce(sum(l.shipments_handled),0)::bigint,
    round(avg(l.avg_clearance_days), 2)
  from public.cha_scorecard_r3671 l
  group by l.shipment_mode, l.performance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly clearance trend
create or replace function public.founder_r3671_monthly_clearance_trend()
returns table(period_month date, scorecards bigint, shipments bigint, avg_clearance_days numeric, avg_first_time_pct numeric, penalty_incidents bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.shipments_handled),0)::bigint,
    round(avg(l.avg_clearance_days), 2),
    round(avg(l.first_time_clearance_pct), 1),
    coalesce(sum(l.penalty_incidents),0)::bigint
  from public.cha_scorecard_r3671 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3671_capa_status_board()
returns table(capa_status text, findings bigint, avg_demurrage_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.demurrage_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cha_scorecard_capa_actions_r3671 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3671_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_demurrage_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cha_scorecard_capa_actions_r3671)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.demurrage_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cha_scorecard_capa_actions_r3671 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Query / doc-error digest per port
create or replace function public.founder_r3671_query_doc_error_digest()
returns table(port_name text, scorecards bigint, avg_query_rate_pct numeric, avg_doc_error_rate_pct numeric, penalty_incidents bigint, total_brokerage_spend_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.port_name,
    count(*)::bigint,
    round(avg(l.query_rate_pct), 1),
    round(avg(l.doc_error_rate_pct), 1),
    coalesce(sum(l.penalty_incidents),0)::bigint,
    coalesce(sum(l.brokerage_spend_rupees),0)::numeric
  from public.cha_scorecard_r3671 l
  group by l.port_name
  order by round(avg(l.query_rate_pct), 1) desc nulls last;
end;
$$;

-- 8) High-risk broker queue (poor / critical / worsening / penalised)
create or replace function public.founder_r3671_high_risk_queue()
returns table(
  broker_name text,
  scorecard_code text,
  port_name text,
  period_month date,
  shipment_mode text,
  performance_status text,
  trend_dir text,
  avg_clearance_days numeric,
  query_rate_pct numeric,
  penalty_incidents int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.broker_name, l.scorecard_code, l.port_name, l.period_month,
    l.shipment_mode, l.performance_status, l.trend_dir,
    l.avg_clearance_days, l.query_rate_pct, l.penalty_incidents, l.notes
  from public.cha_scorecard_r3671 l
  where l.performance_status in ('poor','critical')
     or l.trend_dir = 'worsening'
     or l.penalty_incidents > 0
     or l.query_rate_pct > 15
     or l.doc_error_rate_pct > 5
  order by l.period_month desc, l.broker_name;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3671_performance_status_rollup() from public, anon;
revoke all on function public.founder_r3671_broker_scorecard() from public, anon;
revoke all on function public.founder_r3671_mode_status_matrix() from public, anon;
revoke all on function public.founder_r3671_monthly_clearance_trend() from public, anon;
revoke all on function public.founder_r3671_capa_status_board() from public, anon;
revoke all on function public.founder_r3671_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3671_query_doc_error_digest() from public, anon;
revoke all on function public.founder_r3671_high_risk_queue() from public, anon;

grant execute on function public.founder_r3671_performance_status_rollup() to authenticated;
grant execute on function public.founder_r3671_broker_scorecard() to authenticated;
grant execute on function public.founder_r3671_mode_status_matrix() to authenticated;
grant execute on function public.founder_r3671_monthly_clearance_trend() to authenticated;
grant execute on function public.founder_r3671_capa_status_board() to authenticated;
grant execute on function public.founder_r3671_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3671_query_doc_error_digest() to authenticated;
grant execute on function public.founder_r3671_high_risk_queue() to authenticated;

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

  -- 16 scorecard rows
  insert into public.cha_scorecard_r3671 (
    organization_id, scorecard_code, broker_name, port_name, period_month,
    shipments_handled, avg_clearance_days, target_clearance_days,
    first_time_clearance_pct, query_rate_pct, penalty_incidents,
    brokerage_spend_rupees, doc_error_rate_pct, shipment_mode,
    performance_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.bname, q.pname, q.pmon::date,
    q.shp, q.acd, q.tcdays,
    q.ftc, q.qrp, q.pen,
    q.spend, q.derr, q.smode,
    q.pstat, q.tdir, q.nt
  from (values
    ('CHA-JEE-NSV-05','Jeena & Company','Nhava Sheva','2026-05-01',
     48,6.8,7.0,82.5,9.2,0,412000,2.1,'sea_import','on_target','stable','Sea imports steady; clearance within SLA'),
    ('CHA-JEE-NSV-06','Jeena & Company','Nhava Sheva','2026-06-01',
     52,6.2,7.0,86.4,7.8,0,448000,1.6,'sea_import','excellent','improving','First-time clearance improved after pre-filing BoE'),
    ('CHA-JEE-NSV-07','Jeena & Company','Nhava Sheva','2026-07-01',
     55,5.9,7.0,88.1,6.9,0,461000,1.4,'sea_import','excellent','improving','Best sea-import lane this quarter'),
    ('CHA-LEX-DEL-05','Lexship Logistics','Delhi Air Cargo','2026-05-01',
     36,2.4,2.0,74.2,14.5,1,286000,4.8,'air_import','slipping','worsening','Query rate climbing on HS codes for monitor spares'),
    ('CHA-LEX-DEL-06','Lexship Logistics','Delhi Air Cargo','2026-06-01',
     34,3.1,2.0,68.9,18.2,2,301000,6.3,'air_import','poor','worsening','Two penalty incidents — late bill-of-entry filing'),
    ('CHA-LEX-DEL-07','Lexship Logistics','Delhi Air Cargo','2026-07-01',
     31,3.6,2.0,61.5,21.7,3,318000,7.9,'air_import','critical','worsening','Escalated: repeated duty misclassification on ICU spares'),
    ('CHA-ACS-CHN-05','ACS Cargo Movers','Chennai Port','2026-05-01',
     22,8.4,8.0,79.0,10.1,0,198000,2.9,'sea_import','on_target','stable','Chennai sea lane nominal'),
    ('CHA-ACS-CHN-06','ACS Cargo Movers','Chennai Port','2026-06-01',
     25,9.6,8.0,71.3,12.8,1,224000,3.7,'sea_import','slipping','worsening','Port congestion added 1.6 days to average clearance'),
    ('CHA-ACS-CHN-07','ACS Cargo Movers','Chennai Port','2026-07-01',
     24,10.8,8.0,62.5,16.4,2,241000,5.5,'sea_import','poor','worsening','Demurrage on two reefer containers — CAPA raised'),
    ('CHA-TRD-MAA-06','Trident Shipping Agency','Chennai Air Cargo','2026-06-01',
     18,1.8,2.0,90.2,5.4,0,142000,1.1,'air_export','excellent','stable','Export docs clean; zero queries on 12 shipments'),
    ('CHA-TRD-MAA-07','Trident Shipping Agency','Chennai Air Cargo','2026-07-01',
     20,1.9,2.0,88.7,6.1,0,151000,1.3,'air_export','on_target','stable','Air exports steady against 2-day target'),
    ('CHA-OMT-BLR-05','OmTrans Logistics','Bengaluru Air Cargo','2026-05-01',
     15,2.7,2.5,80.0,9.8,0,118000,2.4,'air_import','on_target','stable','Bengaluru air imports within target band'),
    ('CHA-OMT-BLR-06','OmTrans Logistics','Bengaluru Air Cargo','2026-06-01',
     17,3.4,2.5,72.6,13.9,1,131000,4.2,'air_import','slipping','worsening','Doc checklist misses after broker staff attrition'),
    ('CHA-SKY-DEL-06','Skyways Air Services','Delhi Air Cargo','2026-06-01',
     12,1.6,2.0,91.7,4.2,0,96000,0.8,'air_export','excellent','improving','Backup export broker performing above target'),
    ('CHA-SKY-DEL-07','Skyways Air Services','Delhi Air Cargo','2026-07-01',
     14,1.5,2.0,92.9,3.6,0,104000,0.7,'air_export','excellent','stable','Candidate to absorb Lexship export volume'),
    ('CHA-JEE-BOM-07','Jeena & Company','Mumbai Air Cargo','2026-07-01',
     40,1.2,1.5,95.0,2.5,0,88000,0.5,'courier_bill','excellent','stable','Courier bill-of-entry clearances near-perfect')
  ) as q(scode, bname, pname, pmon, shp, acd, tcdays, ftc, qrp, pen, spend, derr, smode, pstat, tdir, nt);

  -- 8 CAPA rows — attach to specific scorecards via scorecard_code
  insert into public.cha_scorecard_capa_actions_r3671 (
    scorecard_id, finding_category, root_cause, corrective_action,
    capa_status, demurrage_cost_rupees, action_owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.dcost, q.ownr,
    q.tgt::date, q.act::date, q.nt
  from (values
    ('CHA-LEX-DEL-06','penalty_incident','late_checklist_submission','retrain_broker_team','in_progress',54000.00,'Imports Lead — Priya Nair','2026-07-15',null,'Broker ops team retraining underway; SLA review scheduled'),
    ('CHA-LEX-DEL-07','duty_misclassification','hs_code_misclassification','escalate_to_broker_management','escalated',112000.00,'Head of SCM — Arvind Menon','2026-07-25',null,'Repeated HS-code errors on ICU spares — MD-level escalation'),
    ('CHA-ACS-CHN-06','clearance_delay','port_congestion','pre_file_bill_of_entry','closed',38000.00,'Logistics Mgr — Kavitha R','2026-07-10','2026-07-08','Pre-filing adopted; clearance back within 8-day target'),
    ('CHA-ACS-CHN-07','shipment_hold','duty_payment_delay','renegotiate_brokerage_sla','open',87500.00,'Finance Ops — Rohit Shah','2026-08-05',null,'Reefer demurrage recovery clause added to draft SLA'),
    ('CHA-OMT-BLR-06','documentation_errors','broker_staff_shortage','implement_doc_checklist','verification_pending',12500.00,'Imports Lead — Priya Nair','2026-07-20',null,'Checklist live; verifying doc-error rate over next 10 bills of entry'),
    ('CHA-LEX-DEL-05','high_query_rate','incomplete_import_docs','automate_doc_validation','in_progress',26000.00,'IT Ops — Sandeep Kulkarni','2026-07-30',null,'OCR-based invoice and packing-list validation pilot on Zoho Creator'),
    ('CHA-LEX-DEL-07','first_time_clearance_drop','sops_not_followed','switch_backup_broker','open',0.00,'Head of SCM — Arvind Menon','2026-08-10',null,'Moving 40 pct of Delhi air-import volume to Skyways from August'),
    ('CHA-ACS-CHN-06','high_query_rate','customs_system_downtime','none_required','closed',0.00,'Logistics Mgr — Kavitha R','2026-07-05','2026-07-03','ICEGATE outage-driven queries — no broker fault established')
  ) as q(scode, fc, rc, ca, cst, dcost, ownr, tgt, act, nt)
  join public.cha_scorecard_r3671 e
    on e.organization_id = v_org_id and e.scorecard_code = q.scode;
end;
$seed$;
