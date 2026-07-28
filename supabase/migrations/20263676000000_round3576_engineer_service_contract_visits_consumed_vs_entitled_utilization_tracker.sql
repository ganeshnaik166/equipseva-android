-- Round 3576: Engineer Service-Contract Visits-Consumed-vs-Entitled Utilization Tracker
-- AMC/CMC contract entitlement — PM/breakdown visits consumed vs entitled utilization × contract type
-- × utilization status × monthly trend × entitlement-impact × CAPA closure

-- =============================================================================
-- TABLE 1: contract_visits_util_r3576 — per-contract visit entitlement utilization
-- =============================================================================
create table if not exists public.contract_visits_util_r3576 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_name text not null,
  contract_code text not null,
  device_model text not null,
  contract_type text not null check (contract_type in (
    'amc','cmc','comprehensive','labor_only','preventive_only'
  )),
  visits_entitled int not null,
  visits_consumed int not null,
  visits_remaining int not null,
  utilization_pct numeric(6,2),
  breakdown_visits int not null,
  pm_visits int not null,
  months_elapsed_pct numeric(6,2),
  utilization_status text not null check (utilization_status in (
    'on_pace','under_utilized','over_consumed','exhausted','breach_risk'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.contract_visits_util_r3576 enable row level security;

create index if not exists idx_contract_visits_util_r3576_org on public.contract_visits_util_r3576(organization_id);
create index if not exists idx_contract_visits_util_r3576_month on public.contract_visits_util_r3576(period_month);
create index if not exists idx_contract_visits_util_r3576_status on public.contract_visits_util_r3576(utilization_status);

-- =============================================================================
-- TABLE 2: contract_visits_util_capa_actions_r3576 — CAPA & entitlement actions
-- =============================================================================
create table if not exists public.contract_visits_util_capa_actions_r3576 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  util_log_id uuid not null references public.contract_visits_util_r3576(id) on delete cascade,
  contract_code text not null,
  finding_category text not null check (finding_category in (
    'entitlement_exhausted','over_consumption','under_utilization','breakdown_spike',
    'pm_schedule_slippage','visit_logging_gap','contract_scope_mismatch','renewal_risk'
  )),
  root_cause text not null check (root_cause in (
    'equipment_reliability_poor','operator_misuse','deferred_pm_backlog','contract_underscoped',
    'seasonal_load_spike','engineer_shortage','logging_process_gap','customer_overcall',
    'pending_investigation','spares_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_entitlement','schedule_catchup_pm','root_cause_repair','retrain_operator',
    'add_engineer_capacity','tighten_visit_logging','escalate_renewal','recover_excess_billing',
    'none_required','oem_escalation'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  entitlement_impact_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.contract_visits_util_capa_actions_r3576 enable row level security;

create index if not exists idx_contract_visits_util_capa_r3576_log on public.contract_visits_util_capa_actions_r3576(util_log_id);
create index if not exists idx_contract_visits_util_capa_r3576_status on public.contract_visits_util_capa_actions_r3576(capa_status);

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

  -- 16 contract utilization rows
  insert into public.contract_visits_util_r3576 (
    organization_id, customer_name, contract_code, device_model, contract_type,
    visits_entitled, visits_consumed, visits_remaining, utilization_pct,
    breakdown_visits, pm_visits, months_elapsed_pct, utilization_status, period_month, notes
  )
  select v_org_id, q.cust, q.ccode, q.dmodel, q.ctype,
    q.vent, q.vcon, q.vrem, q.upct,
    q.bd, q.pm, q.mep, q.ustat, q.pmon::date, q.nt
  from (values
    ('Apollo Chennai','AMC-APL-001','GE Vivid E95 Ultrasound','amc',
     12,7,5,58.33,2,5,50.0,'on_pace','2026-07-01','H1 AMC tracking on pace, PM cadence steady'),
    ('Apollo Chennai','CMC-APL-002','Philips MRI Ingenia 1.5T','comprehensive',
     24,22,2,91.67,9,13,50.0,'over_consumed','2026-07-01','Breakdown-heavy MRI, consumption ahead of elapsed months'),
    ('Fortis Gurgaon','AMC-FRT-011','Siemens CT Somatom','cmc',
     12,12,0,100.0,7,5,66.7,'exhausted','2026-07-01','All visits consumed with 4 months left — entitlement exhausted'),
    ('Fortis Gurgaon','AMC-FRT-012','Mindray Ventilator SV800','amc',
     8,3,5,37.5,1,2,66.7,'under_utilized','2026-07-01','Low utilization vs elapsed period — PM catch-up due'),
    ('Manipal Bengaluru','CMC-MNP-021','Drager Anaesthesia Perseus','comprehensive',
     16,15,1,93.75,6,9,58.3,'breach_risk','2026-07-01','Nearing entitlement with two quarters remaining — breach risk'),
    ('Manipal Bengaluru','AMC-MNP-022','Nihon Kohden Monitor','preventive_only',
     6,3,3,50.0,0,3,50.0,'on_pace','2026-07-01','Preventive-only contract on pace'),
    ('AIIMS Delhi','AMC-AIM-031','GE Ventilator Carescape','amc',
     12,5,7,41.67,2,3,58.3,'under_utilized','2026-06-01','Utilization lagging elapsed months'),
    ('AIIMS Delhi','CMC-AIM-032','Siemens Cath Lab Artis','comprehensive',
     24,26,-2,108.33,12,14,66.7,'over_consumed','2026-06-01','Consumed beyond entitlement — excess billing review'),
    ('CMC Vellore','AMC-CMC-041','Roche Cobas Analyzer','labor_only',
     8,6,2,75.0,3,3,58.3,'on_pace','2026-06-01','Labor-only AMC tracking well'),
    ('CMC Vellore','CMC-CMC-042','Getinge Sterilizer','cmc',
     10,10,0,100.0,4,6,75.0,'exhausted','2026-06-01','Entitlement exhausted at 9 months elapsed'),
    ('KIMS Hyderabad','AMC-KIM-051','Philips Defibrillator','preventive_only',
     4,1,3,25.0,0,1,50.0,'under_utilized','2026-06-01','PM visits behind schedule'),
    ('KIMS Hyderabad','CMC-KIM-052','GE MRI Signa','comprehensive',
     24,23,1,95.83,10,13,66.7,'breach_risk','2026-06-01','High breakdown load, remaining visits thin'),
    ('Yashoda Hyderabad','AMC-YSH-061','Mindray Ultrasound','amc',
     12,8,4,66.67,3,5,66.7,'on_pace','2026-05-01','On pace mid-contract'),
    ('Yashoda Hyderabad','CMC-YSH-062','Trivitron C-Arm','cmc',
     16,17,-1,106.25,8,9,75.0,'over_consumed','2026-05-01','Over-consumed, contract scope mismatch suspected'),
    ('Kokilaben Mumbai','AMC-KKB-071','Skanray Ventilator','labor_only',
     8,2,6,25.0,1,1,50.0,'under_utilized','2026-05-01','Very low utilization — verify visit logging'),
    ('Kokilaben Mumbai','CMC-KKB-072','Canon CT Aquilion','comprehensive',
     24,24,0,100.0,11,13,66.7,'exhausted','2026-05-01','Entitlement fully consumed early — renewal escalation')
  ) as q(cust, ccode, dmodel, ctype, vent, vcon, vrem, upct, bd, pm, mep, ustat, pmon, nt);

  -- CAPA seed — attach to specific contracts via contract_code
  insert into public.contract_visits_util_capa_actions_r3576 (
    organization_id, util_log_id, contract_code, finding_category, root_cause, corrective_action,
    capa_status, entitlement_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.ccode, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CMC-APL-002','over_consumption','equipment_reliability_poor','root_cause_repair','in_progress',85000.00,'R. Kannan','2026-08-10',null,'MRI breakdowns driving over-consumption; RCA repair underway'),
    ('AMC-FRT-011','entitlement_exhausted','seasonal_load_spike','renegotiate_entitlement','open',120000.00,'S. Mehta','2026-08-05',null,'CT AMC visits exhausted early — renegotiate entitlement for balance period'),
    ('CMC-MNP-021','renewal_risk','deferred_pm_backlog','schedule_catchup_pm','escalated',60000.00,'A. Rao','2026-08-01',null,'Anaesthesia CMC near breach — PM catch-up and renewal escalation'),
    ('CMC-AIM-032','over_consumption','contract_underscoped','recover_excess_billing','verification_pending',150000.00,'P. Nair','2026-08-12',null,'Cath lab consumed beyond entitlement — recover excess billing'),
    ('AMC-FRT-012','under_utilization','logging_process_gap','tighten_visit_logging','open',0.00,'S. Mehta','2026-08-15',null,'Ventilator visits under-logged — tighten field logging'),
    ('CMC-CMC-042','entitlement_exhausted','engineer_shortage','add_engineer_capacity','overdue',95000.00,'J. Thomas','2026-07-20',null,'Sterilizer entitlement exhausted; engineer shortage in region'),
    ('CMC-KIM-052','breakdown_spike','equipment_reliability_poor','oem_escalation','in_progress',110000.00,'V. Reddy','2026-08-08',null,'MRI breakdown spike, remaining visits thin — OEM escalation'),
    ('CMC-YSH-062','contract_scope_mismatch','customer_overcall','renegotiate_entitlement','closed',40000.00,'K. Menon','2026-07-15','2026-07-18','C-arm over-consumption from customer over-calls — scope corrected'),
    ('CMC-KKB-072','renewal_risk','seasonal_load_spike','escalate_renewal','open',130000.00,'K. Menon','2026-08-20',null,'CT entitlement fully consumed early — renewal escalation raised')
  ) as q(ccode, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.contract_visits_util_r3576 e
    on e.organization_id = v_org_id and e.contract_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Utilization status distribution
create or replace function public.founder_r3576_utilization_status_rollup()
returns table(utilization_status text, contracts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.contract_visits_util_r3576)
  select l.utilization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.contract_visits_util_r3576 l
  group by l.utilization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_utilization_status_rollup() from public, anon;
grant execute on function public.founder_r3576_utilization_status_rollup() to authenticated;

-- 2) Contract-type scorecard
create or replace function public.founder_r3576_contract_type_scorecard()
returns table(
  contract_type text,
  contracts bigint,
  total_entitled bigint,
  total_consumed bigint,
  total_remaining bigint,
  avg_utilization_pct numeric,
  over_consumed bigint,
  exhausted bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_type,
    count(*)::bigint,
    coalesce(sum(l.visits_entitled),0)::bigint,
    coalesce(sum(l.visits_consumed),0)::bigint,
    coalesce(sum(l.visits_remaining),0)::bigint,
    round(avg(l.utilization_pct), 1),
    count(*) filter (where l.utilization_status = 'over_consumed')::bigint,
    count(*) filter (where l.utilization_status = 'exhausted')::bigint
  from public.contract_visits_util_r3576 l
  group by l.contract_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_contract_type_scorecard() from public, anon;
grant execute on function public.founder_r3576_contract_type_scorecard() to authenticated;

-- 3) Contract-type × utilization-status matrix
create or replace function public.founder_r3576_contract_type_status_matrix()
returns table(contract_type text, utilization_status text, contracts bigint, avg_utilization_pct numeric, total_breakdown_visits bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_type, l.utilization_status, count(*)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.breakdown_visits),0)::bigint
  from public.contract_visits_util_r3576 l
  group by l.contract_type, l.utilization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_contract_type_status_matrix() from public, anon;
grant execute on function public.founder_r3576_contract_type_status_matrix() to authenticated;

-- 4) Monthly visit trend
create or replace function public.founder_r3576_monthly_visit_trend()
returns table(period_month date, contracts bigint, total_consumed bigint, total_pm bigint, total_breakdown bigint, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.visits_consumed),0)::bigint,
    coalesce(sum(l.pm_visits),0)::bigint,
    coalesce(sum(l.breakdown_visits),0)::bigint,
    round(avg(l.utilization_pct), 1)
  from public.contract_visits_util_r3576 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3576_monthly_visit_trend() from public, anon;
grant execute on function public.founder_r3576_monthly_visit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3576_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.entitlement_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.contract_visits_util_capa_actions_r3576 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_capa_status_board() from public, anon;
grant execute on function public.founder_r3576_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3576_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.contract_visits_util_capa_actions_r3576)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.entitlement_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.contract_visits_util_capa_actions_r3576 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3576_root_cause_pareto() to authenticated;

-- 7) Entitlement-impact digest (by finding category)
create or replace function public.founder_r3576_entitlement_impact_digest()
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
    coalesce(sum(c.entitlement_impact_rupees),0)::numeric
  from public.contract_visits_util_capa_actions_r3576 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3576_entitlement_impact_digest() from public, anon;
grant execute on function public.founder_r3576_entitlement_impact_digest() to authenticated;

-- 8) High-risk queue (over-consumed / exhausted / breach-risk contracts)
create or replace function public.founder_r3576_high_risk_queue()
returns table(
  customer_name text,
  contract_code text,
  device_model text,
  contract_type text,
  period_month date,
  utilization_status text,
  visits_entitled int,
  visits_consumed int,
  visits_remaining int,
  utilization_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.contract_code, l.device_model, l.contract_type, l.period_month,
    l.utilization_status, l.visits_entitled, l.visits_consumed, l.visits_remaining, l.utilization_pct, l.notes
  from public.contract_visits_util_r3576 l
  where l.utilization_status in ('over_consumed','exhausted','breach_risk')
  order by l.utilization_pct desc nulls last, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3576_high_risk_queue() from public, anon;
grant execute on function public.founder_r3576_high_risk_queue() to authenticated;
