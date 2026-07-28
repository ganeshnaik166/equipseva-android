-- Round 3564: Engineer Parts Core-Exchange / Return-for-Credit Tracker
-- Repairable-part core-exchange / return-for-credit tracker — engineer × part × supplier × core type ×
-- core status × core value × credit received × days outstanding × return deadline × within-deadline × CAPA

-- =============================================================================
-- TABLE 1: core_exchange_r3564 — per-core exchange / return-for-credit records
-- =============================================================================
create table if not exists public.core_exchange_r3564 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  core_ref text not null,
  engineer_name text not null,
  part_name text not null,
  part_serial text not null,
  supplier_name text not null,
  core_type text not null check (core_type in (
    'probe','board','battery','detector','tube','module','handpiece'
  )),
  core_status text not null check (core_status in (
    'pending_return','shipped','received_oem','credited','rejected','scrapped'
  )),
  core_value_rupees numeric(12,2),
  credit_received_rupees numeric(12,2),
  days_outstanding int,
  return_deadline date,
  within_deadline boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.core_exchange_r3564 enable row level security;

create index if not exists idx_core_exchange_r3564_org on public.core_exchange_r3564(organization_id);
create index if not exists idx_core_exchange_r3564_status on public.core_exchange_r3564(core_status);
create index if not exists idx_core_exchange_r3564_deadline on public.core_exchange_r3564(return_deadline);

-- =============================================================================
-- TABLE 2: core_exchange_capa_actions_r3564 — CAPA & credit-recovery actions
-- =============================================================================
create table if not exists public.core_exchange_capa_actions_r3564 (
  id uuid primary key default gen_random_uuid(),
  core_log_id uuid not null references public.core_exchange_r3564(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'core_not_returned','return_shipment_delayed','core_rejected_by_oem','credit_short_paid',
    'credit_not_received','wrong_core_shipped','core_damaged_in_transit','deadline_missed',
    'high_value_core_at_risk','documentation_missing'
  )),
  root_cause text not null check (root_cause in (
    'engineer_delay','logistics_delay','oem_inspection_failure','packaging_inadequate',
    'wrong_part_pulled','paperwork_error','supplier_dispute','core_physically_damaged',
    'no_return_tracking','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_return_shipment','escalate_to_oem','refile_credit_claim','improve_packaging',
    'retrain_engineer','resubmit_documentation','writeoff_core_value','replace_wrong_core','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  credit_impact_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.core_exchange_capa_actions_r3564 enable row level security;

create index if not exists idx_core_exchange_capa_r3564_log on public.core_exchange_capa_actions_r3564(core_log_id);
create index if not exists idx_core_exchange_capa_r3564_status on public.core_exchange_capa_actions_r3564(capa_status);

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

  -- 16 core-exchange rows
  insert into public.core_exchange_r3564 (
    organization_id, core_ref, engineer_name, part_name, part_serial, supplier_name,
    core_type, core_status, core_value_rupees, credit_received_rupees, days_outstanding,
    return_deadline, within_deadline, notes
  )
  select v_org_id, q.cref, q.eng, q.pname, q.pser, q.sup,
    q.ctype, q.cstat, q.cval, q.credit, q.dout,
    q.deadline::date, q.within, q.nt
  from (values
    ('CX-3564-01','Ramesh Kumar','Ultrasound TEE Probe','TEE-778812','GE Healthcare India',
     'probe','credited',185000,175000,18,'2026-06-20',true,'TEE probe core returned and credited, minor wear deduction'),
    ('CX-3564-02','Suresh Nair','CT Detector Module','DET-4471','Siemens Healthineers',
     'detector','shipped',420000,0,9,'2026-07-15',true,'CT detector core shipped to OEM, awaiting inspection'),
    ('CX-3564-03','Priya Sharma','Defib Battery Pack','BAT-9921','Philips India',
     'battery','pending_return',12000,0,25,'2026-07-05',false,'Defib battery core still with engineer, past pickup date'),
    ('CX-3564-04','Anil Deshmukh','X-Ray Tube Assembly','XRT-1123','Canon Medical India',
     'tube','received_oem',560000,0,14,'2026-07-18',true,'X-ray tube core received by OEM, credit note pending'),
    ('CX-3564-05','Meena Iyer','Patient Monitor Board','PMB-3390','Mindray India',
     'board','rejected',48000,0,40,'2026-06-10',false,'Board core rejected by OEM for broken tamper seal'),
    ('CX-3564-06','Rajesh Gupta','Endoscope Handpiece','HND-5567','Olympus India',
     'handpiece','credited',96000,90000,12,'2026-06-25',true,'Endoscope handpiece core credited after refurb assessment'),
    ('CX-3564-07','Kavita Reddy','Ventilator Module','VMOD-2218','Drager India',
     'module','scrapped',75000,0,55,'2026-05-28',false,'Ventilator module core damaged in transit, scrapped'),
    ('CX-3564-08','Vikram Singh','Ultrasound Linear Probe','LIN-6634','GE Healthcare India',
     'probe','shipped',132000,0,7,'2026-07-20',true,'Linear probe core shipped with RMA, tracking active'),
    ('CX-3564-09','Deepak Joshi','MRI Gradient Board','MRB-8890','Siemens Healthineers',
     'board','pending_return',310000,0,33,'2026-07-02',false,'High-value gradient board core awaiting engineer return, overdue'),
    ('CX-3564-10','Sunita Rao','CT X-Ray Tube','CTT-4402','Philips India',
     'tube','credited',680000,650000,20,'2026-06-18',true,'CT tube core returned within window, full credit less handling'),
    ('CX-3564-11','Arun Menon','Cath Lab Detector','CLD-7745','Canon Medical India',
     'detector','received_oem',495000,0,16,'2026-07-16',true,'Cath lab detector core at OEM inspection queue'),
    ('CX-3564-12','Neha Kulkarni','Infusion Pump Battery','IPB-1190','Mindray India',
     'battery','credited',9000,8500,10,'2026-06-28',true,'Infusion pump battery core credited on schedule'),
    ('CX-3564-13','Sanjay Patil','Anesthesia Module','AMOD-3312','Drager India',
     'module','rejected',88000,0,45,'2026-06-05',false,'Anesthesia module core rejected, missing calibration data'),
    ('CX-3564-14','Pooja Verma','Ultrasound Phased Probe','PHS-9980','GE Healthcare India',
     'probe','pending_return',210000,0,28,'2026-07-08',false,'Phased-array probe core delayed at branch, high value at risk'),
    ('CX-3564-15','Manoj Tiwari','Laparoscope Handpiece','LHP-2276','Olympus India',
     'handpiece','shipped',64000,0,6,'2026-07-22',true,'Laparoscope handpiece core dispatched, RMA logged'),
    ('CX-3564-16','Rekha Nanda','Portable X-Ray Tube','PXT-5541','Canon Medical India',
     'tube','scrapped',145000,0,60,'2026-05-20',false,'Portable X-ray tube core scrapped after OEM deemed it unrepairable')
  ) as q(cref, eng, pname, pser, sup, ctype, cstat, cval, credit, dout, deadline, within, nt);

  -- CAPA seed — attach to specific cores via core_ref
  insert into public.core_exchange_capa_actions_r3564 (
    core_log_id, finding_category, root_cause, corrective_action,
    capa_status, credit_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.owner, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CX-3564-03','return_shipment_delayed','engineer_delay','expedite_return_shipment','in_progress',12000,'Regional Service Lead','2026-07-30',null,'Battery core pickup escalated to engineer, courier booked'),
    ('CX-3564-05','core_rejected_by_oem','oem_inspection_failure','escalate_to_oem','escalated',48000,'OEM Liaison','2026-07-25',null,'Monitor board rejection under dispute with OEM QA'),
    ('CX-3564-07','core_damaged_in_transit','packaging_inadequate','improve_packaging','closed',75000,'Logistics Coordinator','2026-06-30','2026-06-29','Damaged module written off; foam-insert packaging SOP updated'),
    ('CX-3564-09','high_value_core_at_risk','engineer_delay','expedite_return_shipment','open',310000,'Regional Service Lead','2026-08-01',null,'Gradient board is highest-value open core, daily follow-up set'),
    ('CX-3564-13','documentation_missing','paperwork_error','resubmit_documentation','in_progress',88000,'Service Admin','2026-07-28',null,'Calibration certificate reissued and resubmitted to OEM'),
    ('CX-3564-14','deadline_missed','logistics_delay','expedite_return_shipment','overdue',210000,'Logistics Coordinator','2026-07-18',null,'Phased probe past deadline at branch, priority pickup arranged'),
    ('CX-3564-16','core_rejected_by_oem','core_physically_damaged','writeoff_core_value','closed',145000,'Finance Controller','2026-06-15','2026-06-12','Portable X-ray tube unrepairable, core value written off'),
    ('CX-3564-01','credit_short_paid','supplier_dispute','refile_credit_claim','verification_pending',10000,'OEM Liaison','2026-07-26',null,'Wear-deduction on TEE probe contested, revised claim filed')
  ) as q(cref, fc, rc, ca, cst, impact, owner, tcd, acd, nt)
  join public.core_exchange_r3564 e
    on e.organization_id = v_org_id and e.core_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Core status distribution
create or replace function public.founder_r3564_core_status_rollup()
returns table(core_status text, cores bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.core_exchange_r3564)
  select l.core_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.core_exchange_r3564 l
  group by l.core_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3564_core_status_rollup() from public, anon;
grant execute on function public.founder_r3564_core_status_rollup() to authenticated;

-- 2) Supplier scorecard
create or replace function public.founder_r3564_supplier_scorecard()
returns table(
  supplier_name text,
  total_cores bigint,
  credited bigint,
  rejected bigint,
  scrapped bigint,
  pending bigint,
  core_value_rupees numeric,
  credit_received_rupees numeric,
  recovery_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name,
    count(*)::bigint,
    count(*) filter (where l.core_status = 'credited')::bigint,
    count(*) filter (where l.core_status = 'rejected')::bigint,
    count(*) filter (where l.core_status = 'scrapped')::bigint,
    count(*) filter (where l.core_status in ('pending_return','shipped','received_oem'))::bigint,
    coalesce(sum(l.core_value_rupees),0)::numeric,
    coalesce(sum(l.credit_received_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.credit_received_rupees),0)::numeric / nullif(sum(l.core_value_rupees),0), 1)
  from public.core_exchange_r3564 l
  group by l.supplier_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3564_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3564_supplier_scorecard() to authenticated;

-- 3) Core type × core status matrix
create or replace function public.founder_r3564_core_type_status_matrix()
returns table(core_type text, core_status text, cores bigint, core_value_rupees numeric, credit_received_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.core_type, l.core_status, count(*)::bigint,
    coalesce(sum(l.core_value_rupees),0)::numeric,
    coalesce(sum(l.credit_received_rupees),0)::numeric
  from public.core_exchange_r3564 l
  group by l.core_type, l.core_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3564_core_type_status_matrix() from public, anon;
grant execute on function public.founder_r3564_core_type_status_matrix() to authenticated;

-- 4) Monthly return trend (by return-deadline month)
create or replace function public.founder_r3564_monthly_return_trend()
returns table(return_month date, cores bigint, credited bigint, rejected bigint, scrapped bigint, credit_received_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.return_deadline)::date,
    count(*)::bigint,
    count(*) filter (where l.core_status = 'credited')::bigint,
    count(*) filter (where l.core_status = 'rejected')::bigint,
    count(*) filter (where l.core_status = 'scrapped')::bigint,
    coalesce(sum(l.credit_received_rupees),0)::numeric
  from public.core_exchange_r3564 l
  where l.return_deadline is not null
  group by date_trunc('month', l.return_deadline)
  order by date_trunc('month', l.return_deadline) desc;
end;
$$;

revoke execute on function public.founder_r3564_monthly_return_trend() from public, anon;
grant execute on function public.founder_r3564_monthly_return_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3564_capa_status_board()
returns table(capa_status text, findings bigint, avg_credit_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.credit_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.core_exchange_capa_actions_r3564 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3564_capa_status_board() from public, anon;
grant execute on function public.founder_r3564_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3564_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_credit_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.core_exchange_capa_actions_r3564)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.credit_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.core_exchange_capa_actions_r3564 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3564_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3564_root_cause_pareto() to authenticated;

-- 7) Credit-recovery impact digest (by core status)
create or replace function public.founder_r3564_credit_recovery_digest()
returns table(
  core_status text,
  cores bigint,
  total_core_value_rupees numeric,
  total_credit_received_rupees numeric,
  credit_gap_rupees numeric,
  recovery_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.core_status,
    count(*)::bigint,
    coalesce(sum(l.core_value_rupees),0)::numeric,
    coalesce(sum(l.credit_received_rupees),0)::numeric,
    (coalesce(sum(l.core_value_rupees),0) - coalesce(sum(l.credit_received_rupees),0))::numeric,
    round(100.0 * coalesce(sum(l.credit_received_rupees),0)::numeric / nullif(sum(l.core_value_rupees),0), 1)
  from public.core_exchange_r3564 l
  group by l.core_status
  order by (coalesce(sum(l.core_value_rupees),0) - coalesce(sum(l.credit_received_rupees),0)) desc;
end;
$$;

revoke execute on function public.founder_r3564_credit_recovery_digest() from public, anon;
grant execute on function public.founder_r3564_credit_recovery_digest() to authenticated;

-- 8) High-risk core queue (rejected / overdue / scrapped / high-value at risk)
create or replace function public.founder_r3564_high_risk_queue()
returns table(
  engineer_name text,
  core_ref text,
  part_name text,
  part_serial text,
  supplier_name text,
  core_type text,
  core_status text,
  core_value_rupees numeric,
  days_outstanding int,
  return_deadline date,
  within_deadline boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.core_ref, l.part_name, l.part_serial, l.supplier_name,
    l.core_type, l.core_status, l.core_value_rupees, l.days_outstanding,
    l.return_deadline, l.within_deadline, l.notes
  from public.core_exchange_r3564 l
  where l.core_status in ('rejected','scrapped')
     or l.within_deadline = false
     or l.days_outstanding > 30
     or (l.core_value_rupees >= 100000 and l.core_status <> 'credited')
  order by l.days_outstanding desc nulls last, l.core_value_rupees desc;
end;
$$;

revoke execute on function public.founder_r3564_high_risk_queue() from public, anon;
grant execute on function public.founder_r3564_high_risk_queue() to authenticated;
