-- Round 3568: Engineer Repair Parts-Consumption Estimate-vs-Actual Variance Tracker
-- Repair parts consumption estimated-at-diagnosis vs actual-consumed variance (quote accuracy) —
-- engineer × hospital × ticket × device × part category × estimated/actual qty × cost variance ×
-- variance reason × monthly trend × CAPA closure

-- =============================================================================
-- TABLE 1: parts_consumption_var_r3568 — per-ticket parts estimate vs actual variance
-- =============================================================================
create table if not exists public.parts_consumption_var_r3568 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  ticket_code text not null,
  device_model text not null,
  part_category text not null check (part_category in (
    'electronic','mechanical','consumable','sensor','battery','cable','other'
  )),
  estimated_qty int not null,
  actual_qty int not null,
  qty_variance int not null,
  estimated_cost_rupees numeric(12,2) not null,
  actual_cost_rupees numeric(12,2) not null,
  cost_variance_pct numeric(7,2),
  variance_reason text not null check (variance_reason in (
    'under_estimated','over_estimated','scope_change','additional_fault','no_fault_found','accurate'
  )),
  repair_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.parts_consumption_var_r3568 enable row level security;

create index if not exists idx_parts_consumption_var_r3568_org on public.parts_consumption_var_r3568(organization_id);
create index if not exists idx_parts_consumption_var_r3568_date on public.parts_consumption_var_r3568(repair_date);
create index if not exists idx_parts_consumption_var_r3568_reason on public.parts_consumption_var_r3568(variance_reason);

-- =============================================================================
-- TABLE 2: parts_consumption_var_capa_actions_r3568 — CAPA & quote-accuracy actions
-- =============================================================================
create table if not exists public.parts_consumption_var_capa_actions_r3568 (
  id uuid primary key default gen_random_uuid(),
  var_log_id uuid not null references public.parts_consumption_var_r3568(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'estimate_under_run','estimate_over_run','scope_creep','undocumented_fault',
    'no_fault_found','excess_consumption','stale_price_master','wrong_part_ordered'
  )),
  root_cause text not null check (root_cause in (
    'incomplete_diagnosis','outdated_price_master','hidden_secondary_fault','engineer_estimation_error',
    'customer_scope_addition','vendor_price_hike','inventory_miscount','pending_investigation','supplier_substitution'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_estimation','update_price_master','improve_diagnosis_checklist','revise_quote_template',
    'tighten_scope_signoff','audit_inventory_counts','escalate_to_vendor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_band text not null check (impact_band in (
    'negligible','minor','moderate','major','critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.parts_consumption_var_capa_actions_r3568 enable row level security;

create index if not exists idx_parts_consumption_var_capa_r3568_log on public.parts_consumption_var_capa_actions_r3568(var_log_id);
create index if not exists idx_parts_consumption_var_capa_r3568_status on public.parts_consumption_var_capa_actions_r3568(capa_status);

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

  -- 16 parts-consumption variance rows
  insert into public.parts_consumption_var_r3568 (
    organization_id, engineer_name, hospital_name, ticket_code, device_model, part_category,
    estimated_qty, actual_qty, qty_variance, estimated_cost_rupees, actual_cost_rupees,
    cost_variance_pct, variance_reason, repair_date, notes
  )
  select v_org_id, q.eng, q.hosp, q.tkt, q.dm, q.pcat,
    q.eqty::int, q.aqty::int, q.qvar::int, q.ecost::numeric, q.acost::numeric,
    q.cvpct::numeric, q.vr, q.rdate::date, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai','TKT-CHN-3001','Philips IntelliVue MX550','electronic',
     2,3,1,8000,12500,56.3,'under_estimated','2026-07-05','Power board plus flex cable needed — only board quoted'),
    ('Suresh Nair','Fortis Bangalore','TKT-BLR-3002','GE Carescape B650','sensor',
     1,1,0,4500,4500,0.0,'accurate','2026-07-04','SpO2 sensor swap matched estimate exactly'),
    ('Anil Verma','Manipal Delhi','TKT-DEL-3003','Drager Fabius GS','mechanical',
     3,2,-1,15000,9800,-34.7,'over_estimated','2026-07-04','Only two valve seals required — one reused'),
    ('Priya Menon','AIIMS Delhi','TKT-DEL-3004','Mindray BeneVision N19','consumable',
     4,6,2,3200,5100,59.4,'additional_fault','2026-07-03','Extra filters after secondary fan fault found'),
    ('Karthik Iyer','CMC Vellore','TKT-VEL-3005','Nihon Kohden BSM-6501','battery',
     2,2,0,6800,7100,4.4,'accurate','2026-07-03','Battery pack pair replaced, minor price drift'),
    ('Ravi Shankar','KIMS Hyderabad','TKT-HYD-3006','Philips Efficia CM12','cable',
     1,3,2,1500,4400,193.3,'scope_change','2026-07-02','Customer added two more ECG trunk cables mid-repair'),
    ('Deepa Rao','Yashoda Hyderabad','TKT-HYD-3007','Siemens Acuson X300','electronic',
     2,2,0,22000,22000,0.0,'accurate','2026-07-02','Ultrasound TX board pair replaced per estimate'),
    ('Manoj Pillai','Kokilaben Mumbai','TKT-MUM-3008','Maquet Servo-i','mechanical',
     5,8,3,18000,31500,75.0,'under_estimated','2026-07-01','Expiratory cassette plus O2 cell block under-scoped'),
    ('Sunita Desai','Ruby Hall Pune','TKT-PUN-3009','Mindray DC-70','sensor',
     1,0,-1,9500,0,-100.0,'no_fault_found','2026-07-01','Probe re-seated, no part needed after retest'),
    ('Vikram Singh','Fortis Mohali','TKT-MOH-3010','GE Datex-Ohmeda Aisys','consumable',
     6,7,1,4200,4900,16.7,'additional_fault','2026-06-30','Extra soda-lime canister after leak found'),
    ('Aditya Ghosh','AMRI Kolkata','TKT-KOL-3011','Philips IntelliVue MX40','battery',
     3,3,0,5400,5600,3.7,'accurate','2026-06-30','Telemetry battery set replaced on estimate'),
    ('Meera Krishnan','Apollo Chennai','TKT-CHN-3012','Drager Evita V500','sensor',
     2,4,2,12000,24500,104.2,'under_estimated','2026-06-29','Flow and O2 sensors both failed — only flow quoted'),
    ('Sanjay Patel','Sterling Ahmedabad','TKT-AHM-3013','Mindray uMEC12','cable',
     2,1,-1,2600,1400,-46.2,'over_estimated','2026-06-29','Single NIBP hose sufficed, spare not used'),
    ('Nisha Reddy','KIMS Hyderabad','TKT-HYD-3014','Nihon Kohden Life Scope','other',
     1,2,1,3800,7200,89.5,'scope_change','2026-06-28','Added mounting bracket kit at customer request'),
    ('Arjun Mehta','Kokilaben Mumbai','TKT-MUM-3015','Maquet Flow-i','electronic',
     4,9,5,26000,61000,134.6,'under_estimated','2026-06-28','Main PCB, PSU and display driver all needed — badly under-scoped'),
    ('Lakshmi Nair','CMC Vellore','TKT-VEL-3016','GE Carescape R860','consumable',
     3,3,0,3600,3550,-1.4,'accurate','2026-06-27','Ventilator filter set matched estimate')
  ) as q(eng, hosp, tkt, dm, pcat, eqty, aqty, qvar, ecost, acost, cvpct, vr, rdate, nt);

  -- 8 CAPA rows — attach to specific tickets via ticket_code
  insert into public.parts_consumption_var_capa_actions_r3568 (
    var_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_band, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ib, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('TKT-CHN-3001','estimate_under_run','incomplete_diagnosis','improve_diagnosis_checklist','in_progress','moderate','2026-07-12',null,4500,'Diagnosis missed flex cable — checklist update in progress'),
    ('TKT-MUM-3008','estimate_under_run','engineer_estimation_error','retrain_estimation','open','major','2026-07-15',null,13500,'Ventilator repair under-scoped by 75% — retrain engineer'),
    ('TKT-MUM-3015','estimate_under_run','incomplete_diagnosis','improve_diagnosis_checklist','escalated','critical','2026-07-10',null,35000,'Anesthesia workstation under-scoped 135% — escalated to service head'),
    ('TKT-CHN-3012','undocumented_fault','hidden_secondary_fault','revise_quote_template','verification_pending','major','2026-07-11',null,12500,'Second sensor fault undocumented at quote — template revised'),
    ('TKT-HYD-3006','scope_creep','customer_scope_addition','tighten_scope_signoff','closed','minor','2026-07-08','2026-07-07',2900,'Extra cables added mid-repair — scope signoff now enforced'),
    ('TKT-DEL-3003','estimate_over_run','outdated_price_master','update_price_master','closed','minor','2026-07-09','2026-07-08',5200,'Over-estimated valve seals — price master corrected'),
    ('TKT-HYD-3014','scope_creep','customer_scope_addition','tighten_scope_signoff','open','negligible','2026-07-14',null,3400,'Bracket kit added at request — document at quote stage'),
    ('TKT-DEL-3004','undocumented_fault','hidden_secondary_fault','improve_diagnosis_checklist','overdue','moderate','2026-07-06',null,1900,'Fan fault found late — filter overuse; CAPA past due')
  ) as q(tkt, fc, rc, ca, cst, ib, tcd, acd, cost, nt)
  join public.parts_consumption_var_r3568 e
    on e.organization_id = v_org_id and e.ticket_code = q.tkt;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Variance-reason distribution
create or replace function public.founder_r3568_variance_reason_rollup()
returns table(variance_reason text, repairs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.parts_consumption_var_r3568)
  select l.variance_reason, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.parts_consumption_var_r3568 l
  group by l.variance_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_variance_reason_rollup() from public, anon;
grant execute on function public.founder_r3568_variance_reason_rollup() to authenticated;

-- 2) Part-category scorecard
create or replace function public.founder_r3568_part_category_scorecard()
returns table(
  part_category text,
  total_repairs bigint,
  accurate bigint,
  under_estimated bigint,
  over_estimated bigint,
  avg_qty_variance numeric,
  avg_cost_variance_pct numeric,
  total_cost_variance_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.part_category,
    count(*)::bigint,
    count(*) filter (where l.variance_reason = 'accurate')::bigint,
    count(*) filter (where l.variance_reason = 'under_estimated')::bigint,
    count(*) filter (where l.variance_reason = 'over_estimated')::bigint,
    round(avg(l.qty_variance), 2),
    round(avg(l.cost_variance_pct), 1),
    round(coalesce(sum(l.actual_cost_rupees - l.estimated_cost_rupees), 0), 0)
  from public.parts_consumption_var_r3568 l
  group by l.part_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_part_category_scorecard() from public, anon;
grant execute on function public.founder_r3568_part_category_scorecard() to authenticated;

-- 3) Part-category × variance-reason matrix
create or replace function public.founder_r3568_category_reason_matrix()
returns table(part_category text, variance_reason text, repairs bigint, avg_qty_variance numeric, avg_cost_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.part_category, l.variance_reason, count(*)::bigint,
    round(avg(l.qty_variance), 2),
    round(avg(l.cost_variance_pct), 1)
  from public.parts_consumption_var_r3568 l
  group by l.part_category, l.variance_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_category_reason_matrix() from public, anon;
grant execute on function public.founder_r3568_category_reason_matrix() to authenticated;

-- 4) Monthly variance trend
create or replace function public.founder_r3568_monthly_variance_trend()
returns table(repair_month date, repairs bigint, under_estimated bigint, over_estimated bigint, avg_cost_variance_pct numeric, total_cost_variance_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.repair_date)::date,
    count(*)::bigint,
    count(*) filter (where l.variance_reason = 'under_estimated')::bigint,
    count(*) filter (where l.variance_reason = 'over_estimated')::bigint,
    round(avg(l.cost_variance_pct), 1),
    round(coalesce(sum(l.actual_cost_rupees - l.estimated_cost_rupees), 0), 0)
  from public.parts_consumption_var_r3568 l
  group by date_trunc('month', l.repair_date)
  order by date_trunc('month', l.repair_date) desc;
end;
$$;

revoke execute on function public.founder_r3568_monthly_variance_trend() from public, anon;
grant execute on function public.founder_r3568_monthly_variance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3568_capa_status_board()
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
  from public.parts_consumption_var_capa_actions_r3568 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_capa_status_board() from public, anon;
grant execute on function public.founder_r3568_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3568_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.parts_consumption_var_capa_actions_r3568)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.parts_consumption_var_capa_actions_r3568 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3568_root_cause_pareto() to authenticated;

-- 7) Cost-variance impact digest
create or replace function public.founder_r3568_cost_variance_impact_digest()
returns table(impact_band text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_band, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.parts_consumption_var_capa_actions_r3568 c
  group by c.impact_band
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3568_cost_variance_impact_digest() from public, anon;
grant execute on function public.founder_r3568_cost_variance_impact_digest() to authenticated;

-- 8) High-risk variance queue (under-estimated / large-variance concerns)
create or replace function public.founder_r3568_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  ticket_code text,
  device_model text,
  part_category text,
  repair_date date,
  variance_reason text,
  qty_variance int,
  cost_variance_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.ticket_code, l.device_model, l.part_category,
    l.repair_date, l.variance_reason, l.qty_variance, l.cost_variance_pct, l.notes
  from public.parts_consumption_var_r3568 l
  where l.variance_reason in ('under_estimated','scope_change','additional_fault')
     or abs(coalesce(l.cost_variance_pct, 0)) >= 50
     or abs(l.qty_variance) >= 2
  order by l.cost_variance_pct desc nulls last, l.repair_date desc;
end;
$$;

revoke execute on function public.founder_r3568_high_risk_queue() from public, anon;
grant execute on function public.founder_r3568_high_risk_queue() to authenticated;
