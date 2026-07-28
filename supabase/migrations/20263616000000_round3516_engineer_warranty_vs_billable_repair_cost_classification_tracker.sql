-- Round 3516: Engineer Warranty-vs-Billable Repair-Cost Classification Tracker
-- Repair-cost classification — warranty vs billable vs goodwill; parts/labor/total cost x recovered amount
-- x classification accuracy x cost recovery/leakage x CAPA closure

-- =============================================================================
-- TABLE 1: warranty_billable_class_r3516 — per-repair cost classification record
-- =============================================================================
create table if not exists public.warranty_billable_class_r3516 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  ticket_code text not null,
  device_model text not null,
  repair_category text not null check (repair_category in (
    'in_warranty','out_of_warranty','amc_covered','goodwill','chargeable','recall'
  )),
  parts_cost_rupees numeric(12,2) not null default 0,
  labor_cost_rupees numeric(12,2) not null default 0,
  total_cost_rupees numeric(12,2) not null default 0,
  recovered_rupees numeric(12,2) not null default 0,
  classification_status text not null check (classification_status in (
    'correct','misclassified','under_review','disputed','corrected'
  )),
  repair_date date not null,
  billable boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warranty_billable_class_r3516 enable row level security;

create index if not exists idx_warranty_billable_class_r3516_org on public.warranty_billable_class_r3516(organization_id);
create index if not exists idx_warranty_billable_class_r3516_date on public.warranty_billable_class_r3516(repair_date);
create index if not exists idx_warranty_billable_class_r3516_status on public.warranty_billable_class_r3516(classification_status);

-- =============================================================================
-- TABLE 2: warranty_billable_class_capa_actions_r3516 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.warranty_billable_class_capa_actions_r3516 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  class_log_id uuid not null references public.warranty_billable_class_r3516(id) on delete cascade,
  ticket_code text not null,
  finding_category text not null check (finding_category in (
    'misclassified_as_warranty','misclassified_as_billable','unrecovered_cost','disputed_charge',
    'goodwill_leakage','amc_scope_gap','recall_not_flagged','pricing_error'
  )),
  root_cause text not null check (root_cause in (
    'warranty_lookup_error','amc_contract_not_checked','engineer_data_entry_error','parts_pricing_stale',
    'customer_dispute','goodwill_policy_misapplied','recall_notice_missed','approval_process_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reclassify_ticket','raise_invoice','issue_credit_note','update_warranty_master','update_amc_scope',
    'retrain_engineer','escalate_to_finance','write_off_goodwill','flag_recall','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warranty_billable_class_capa_actions_r3516 enable row level security;

create index if not exists idx_warranty_billable_capa_r3516_org on public.warranty_billable_class_capa_actions_r3516(organization_id);
create index if not exists idx_warranty_billable_capa_r3516_log on public.warranty_billable_class_capa_actions_r3516(class_log_id);
create index if not exists idx_warranty_billable_capa_r3516_status on public.warranty_billable_class_capa_actions_r3516(capa_status);

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

  -- 16 repair classification rows
  insert into public.warranty_billable_class_r3516 (
    organization_id, engineer_name, hospital_name, ticket_code, device_model, repair_category,
    parts_cost_rupees, labor_cost_rupees, total_cost_rupees, recovered_rupees,
    classification_status, repair_date, billable, notes
  )
  select v_org_id, q.eng, q.hosp, q.tkt, q.model, q.cat,
    q.parts, q.labor, q.total, q.recov,
    q.cstat, q.rdate::date, q.bill, q.nt
  from (values
    ('Ramesh Kumar','Apollo Chennai','WRT-APL-1001','GE Vivid S60 Ultrasound','in_warranty',
     0,0,0,0,'correct','2026-07-03',false,'In-warranty probe replacement covered by OEM — correctly zero-billed'),
    ('Ramesh Kumar','Apollo Chennai','WRT-APL-1002','Philips IntelliVue MX550','chargeable',
     8500,3000,11500,11500,'correct','2026-07-04',true,'Out-of-warranty monitor module — billed and recovered in full'),
    ('Suresh Reddy','Fortis Gurgaon','WRT-FRT-1003','Mindray BeneVision N22','amc_covered',
     4200,2500,6700,0,'correct','2026-07-02',false,'AMC-covered SpO2 board swap — no separate charge, correctly classified'),
    ('Suresh Reddy','Fortis Gurgaon','WRT-FRT-1004','Drager Fabius GS Anesthesia','out_of_warranty',
     15000,5000,20000,0,'misclassified','2026-07-01',false,'Logged as warranty but unit out of warranty — cost leakage, not billed'),
    ('Anita Desai','Manipal Bengaluru','WRT-MNP-1005','GE Carescape B650','goodwill',
     2000,1500,3500,0,'correct','2026-06-30',false,'Goodwill repair for long-standing customer — approved write-off'),
    ('Anita Desai','Manipal Bengaluru','WRT-MNP-1006','Siemens Acuson Sequoia','chargeable',
     32000,8000,40000,18000,'disputed','2026-06-29',true,'Customer disputing labor charge — partial recovery, balance pending'),
    ('Vikram Singh','AIIMS Delhi','WRT-AIM-1007','Nihon Kohden BSM-6701','recall',
     12000,0,12000,0,'correct','2026-06-28',false,'OEM recall repair — parts free under recall, correctly flagged'),
    ('Vikram Singh','AIIMS Delhi','WRT-AIM-1008','Maquet Servo-u Ventilator','out_of_warranty',
     22000,6000,28000,28000,'correct','2026-06-27',true,'Ventilator turbine — out of warranty, billed and recovered'),
    ('Priya Nair','CMC Vellore','WRT-CMC-1009','GE Logiq P9','amc_covered',
     5500,2000,7500,7500,'misclassified','2026-06-26',true,'AMC-covered but wrongly billed to customer — credit note due'),
    ('Priya Nair','CMC Vellore','WRT-CMC-1010','Philips Affiniti 70','chargeable',
     9000,3500,12500,0,'under_review','2026-06-25',true,'Chargeable transducer repair — invoice pending finance review'),
    ('Rahul Mehta','KIMS Hyderabad','WRT-KIM-1011','Mindray DC-70','in_warranty',
     0,0,0,0,'correct','2026-06-24',false,'In-warranty console board replacement — OEM covered'),
    ('Rahul Mehta','KIMS Hyderabad','WRT-KIM-1012','Drager Evita V500','out_of_warranty',
     18000,7000,25000,0,'disputed','2026-06-23',true,'Customer contests out-of-warranty status — awaiting warranty proof'),
    ('Deepa Iyer','Yashoda Hyderabad','WRT-YSH-1013','GE Vivid E95','goodwill',
     3000,2000,5000,0,'corrected','2026-06-22',false,'Initially billed, reclassified as goodwill after review — corrected'),
    ('Deepa Iyer','Yashoda Hyderabad','WRT-YSH-1014','Canon Aplio i800','chargeable',
     28000,9000,37000,37000,'correct','2026-06-21',true,'Premium ultrasound board — billed and recovered fully'),
    ('Arjun Rao','Kokilaben Mumbai','WRT-KKB-1015','Philips Azurion 7','recall',
     0,4000,4000,0,'misclassified','2026-06-20',true,'Recall labor wrongly billed to customer — should be OEM-borne'),
    ('Arjun Rao','Kokilaben Mumbai','WRT-KKB-1016','Siemens Cios Alpha C-arm','out_of_warranty',
     45000,12000,57000,20000,'under_review','2026-06-19',true,'High-value detector — partial recovery, balance under review')
  ) as q(eng, hosp, tkt, model, cat, parts, labor, total, recov, cstat, rdate, bill, nt);

  -- CAPA seed — attach to specific classification rows via ticket_code
  insert into public.warranty_billable_class_capa_actions_r3516 (
    organization_id, class_log_id, ticket_code, finding_category, root_cause, corrective_action,
    capa_status, recovery_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.tkt, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('WRT-FRT-1004','misclassified_as_warranty','warranty_lookup_error','raise_invoice','open',
     20000,'Finance Ops','2026-07-12',null,'Out-of-warranty repair logged as warranty — invoice to be raised to recover cost'),
    ('WRT-MNP-1006','disputed_charge','customer_dispute','escalate_to_finance','in_progress',
     22000,'Regional Manager','2026-07-11',null,'Customer disputing labor — 18k recovered, 22k balance escalated'),
    ('WRT-CMC-1009','amc_scope_gap','amc_contract_not_checked','issue_credit_note','verification_pending',
     7500,'AMC Desk','2026-07-09',null,'AMC-covered ticket wrongly billed — credit note issued, verifying confirmation'),
    ('WRT-CMC-1010','unrecovered_cost','approval_process_gap','raise_invoice','open',
     12500,'Finance Ops','2026-07-13',null,'Chargeable repair invoice stuck in finance review — release pending'),
    ('WRT-KIM-1012','disputed_charge','pending_investigation','escalate_to_finance','escalated',
     25000,'Legal and Contracts','2026-07-08',null,'Customer contests out-of-warranty status — warranty proof under investigation'),
    ('WRT-YSH-1013','goodwill_leakage','goodwill_policy_misapplied','write_off_goodwill','closed',
     5000,'Service Head','2026-07-02','2026-06-28','Reclassified to goodwill per policy — write-off approved and closed'),
    ('WRT-KKB-1015','recall_not_flagged','recall_notice_missed','flag_recall','overdue',
     4000,'Compliance','2026-07-05',null,'Recall labor wrongly billed to customer — recall flag past due, credit pending'),
    ('WRT-KKB-1016','unrecovered_cost','parts_pricing_stale','escalate_to_finance','in_progress',
     37000,'Finance Ops','2026-07-14',null,'C-arm detector balance 37k unrecovered — pricing revalidation and recovery in progress')
  ) as q(tkt, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.warranty_billable_class_r3516 e
    on e.organization_id = v_org_id and e.ticket_code = q.tkt;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Classification status distribution
create or replace function public.founder_r3516_classification_status_rollup()
returns table(classification_status text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_billable_class_r3516)
  select l.classification_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.warranty_billable_class_r3516 l
  group by l.classification_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3516_classification_status_rollup() from public, anon;
grant execute on function public.founder_r3516_classification_status_rollup() to authenticated;

-- 2) Repair-category scorecard
create or replace function public.founder_r3516_repair_category_scorecard()
returns table(
  repair_category text,
  tickets bigint,
  total_cost_rupees numeric,
  recovered_rupees numeric,
  unrecovered_rupees numeric,
  recovery_pct numeric,
  misclassified bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.repair_category,
    count(*)::bigint,
    coalesce(sum(l.total_cost_rupees),0)::numeric,
    coalesce(sum(l.recovered_rupees),0)::numeric,
    coalesce(sum(l.total_cost_rupees - l.recovered_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.recovered_rupees),0)::numeric / nullif(sum(l.total_cost_rupees),0), 1),
    count(*) filter (where l.classification_status in ('misclassified','disputed','under_review'))::bigint
  from public.warranty_billable_class_r3516 l
  group by l.repair_category
  order by coalesce(sum(l.total_cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3516_repair_category_scorecard() from public, anon;
grant execute on function public.founder_r3516_repair_category_scorecard() to authenticated;

-- 3) Repair-category x classification-status matrix
create or replace function public.founder_r3516_category_status_matrix()
returns table(
  repair_category text,
  classification_status text,
  tickets bigint,
  total_cost_rupees numeric,
  recovered_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.repair_category, l.classification_status, count(*)::bigint,
    coalesce(sum(l.total_cost_rupees),0)::numeric,
    coalesce(sum(l.recovered_rupees),0)::numeric
  from public.warranty_billable_class_r3516 l
  group by l.repair_category, l.classification_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3516_category_status_matrix() from public, anon;
grant execute on function public.founder_r3516_category_status_matrix() to authenticated;

-- 4) Monthly cost trend
create or replace function public.founder_r3516_monthly_cost_trend()
returns table(
  repair_month date,
  tickets bigint,
  total_cost_rupees numeric,
  recovered_rupees numeric,
  unrecovered_rupees numeric,
  misclassified bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.repair_date)::date,
    count(*)::bigint,
    coalesce(sum(l.total_cost_rupees),0)::numeric,
    coalesce(sum(l.recovered_rupees),0)::numeric,
    coalesce(sum(l.total_cost_rupees - l.recovered_rupees),0)::numeric,
    count(*) filter (where l.classification_status in ('misclassified','disputed','under_review'))::bigint
  from public.warranty_billable_class_r3516 l
  group by date_trunc('month', l.repair_date)
  order by date_trunc('month', l.repair_date) desc;
end;
$$;

revoke execute on function public.founder_r3516_monthly_cost_trend() from public, anon;
grant execute on function public.founder_r3516_monthly_cost_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3516_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.warranty_billable_class_capa_actions_r3516 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3516_capa_status_board() from public, anon;
grant execute on function public.founder_r3516_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3516_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_billable_class_capa_actions_r3516)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.warranty_billable_class_capa_actions_r3516 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3516_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3516_root_cause_pareto() to authenticated;

-- 7) Cost-recovery impact digest (by CAPA finding category)
create or replace function public.founder_r3516_finding_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric
  from public.warranty_billable_class_capa_actions_r3516 c
  group by c.finding_category
  order by coalesce(sum(c.recovery_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3516_finding_impact_digest() from public, anon;
grant execute on function public.founder_r3516_finding_impact_digest() to authenticated;

-- 8) High-risk queue (misclassified / disputed / unrecovered)
create or replace function public.founder_r3516_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  ticket_code text,
  device_model text,
  repair_category text,
  classification_status text,
  total_cost_rupees numeric,
  recovered_rupees numeric,
  unrecovered_rupees numeric,
  repair_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.ticket_code, l.device_model, l.repair_category,
    l.classification_status, l.total_cost_rupees, l.recovered_rupees,
    (l.total_cost_rupees - l.recovered_rupees)::numeric, l.repair_date, l.notes
  from public.warranty_billable_class_r3516 l
  where l.classification_status in ('misclassified','disputed','under_review')
     or l.total_cost_rupees > l.recovered_rupees
  order by (l.total_cost_rupees - l.recovered_rupees) desc, l.repair_date desc;
end;
$$;

revoke execute on function public.founder_r3516_high_risk_queue() from public, anon;
grant execute on function public.founder_r3516_high_risk_queue() to authenticated;
