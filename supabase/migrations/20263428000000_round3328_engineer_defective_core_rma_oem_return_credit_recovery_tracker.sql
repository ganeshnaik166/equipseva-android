-- Round 3328: Engineer Defective-Core / Faulty-Part RMA-to-OEM Return & Credit-Recovery Tracker
-- Supply-chain reverse-logistics log — equipment type × return reason × OEM vendor × aging bucket × credit recovery × CAPA
-- When a warranty part or exchange-core is replaced, the faulty unit must be returned to the OEM for credit or core-exchange;
-- failure to return means direct financial loss. This tracks each RMA case and the follow-up/escalation CAPA for overdue ones.

-- =============================================================================
-- TABLE 1: core_rma_r3328 — per-RMA defective-core return & credit-recovery case
-- =============================================================================
create table if not exists public.core_rma_r3328 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  rma_code text not null,
  oem_vendor text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','imaging','dialysis','infusion_pump','ventilator','lab_analyzer'
  )),
  part_description text not null,
  return_reason text not null check (return_reason in (
    'warranty_defect','core_exchange','doa_dead_on_arrival','wrong_part','recall_return'
  )),
  part_value_rupees numeric(12,2) not null,
  rma_raised_date date not null,
  dispatch_date date,
  oem_received_confirmed boolean not null default false,
  credit_note_received boolean not null default false,
  credit_amount_rupees numeric(12,2) not null default 0,
  days_pending int not null default 0,
  aging_bucket text not null check (aging_bucket in (
    '0_30','31_60','61_90','over_90'
  )),
  rma_verdict text not null check (rma_verdict in (
    'closed_credited','in_transit','awaiting_oem','overdue_no_credit','write_off_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.core_rma_r3328 enable row level security;

create index if not exists idx_core_rma_r3328_org on public.core_rma_r3328(organization_id);
create index if not exists idx_core_rma_r3328_date on public.core_rma_r3328(rma_raised_date);
create index if not exists idx_core_rma_r3328_verdict on public.core_rma_r3328(rma_verdict);

-- =============================================================================
-- TABLE 2: core_rma_capa_actions_r3328 — follow-up / escalation actions for overdue RMAs
-- =============================================================================
create table if not exists public.core_rma_capa_actions_r3328 (
  id uuid primary key default gen_random_uuid(),
  rma_id uuid not null references public.core_rma_r3328(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dispatch_delay','oem_no_acknowledgement','credit_note_missing','wrong_part_returned',
    'documentation_gap','logistics_lost_in_transit','write_off_pending'
  )),
  root_cause text not null check (root_cause in (
    'courier_delay','oem_process_backlog','paperwork_incomplete','serial_mismatch',
    'rma_code_error','warranty_dispute','internal_tracking_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_dispatch','escalate_to_oem_account_manager','resubmit_documentation','raise_debit_note',
    'initiate_write_off','retrain_field_engineer','engage_logistics_partner','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'credit_recovered','credit_at_risk','partial_credit','full_write_off','no_impact','disputed'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovery_amount_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.core_rma_capa_actions_r3328 enable row level security;

create index if not exists idx_core_rma_capa_r3328_rma on public.core_rma_capa_actions_r3328(rma_id);
create index if not exists idx_core_rma_capa_r3328_status on public.core_rma_capa_actions_r3328(capa_status);

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

  -- 14 RMA case rows
  insert into public.core_rma_r3328 (
    organization_id, engineer_name, region, rma_code, oem_vendor, equipment_type,
    part_description, return_reason, part_value_rupees, rma_raised_date, dispatch_date,
    oem_received_confirmed, credit_note_received, credit_amount_rupees, days_pending,
    aging_bucket, rma_verdict, notes
  )
  select v_org_id, q.eng, q.region, q.rma, q.oem, q.eqt,
    q.pd, q.rr, q.pv::numeric, q.rrd::date, q.dd::date,
    q.orc, q.cnr, q.ca::numeric, q.dp::int,
    q.ab, q.rv, q.nt
  from (values
    ('Rajesh Kumar','South - Chennai','RMA-2026-0431','GE Healthcare','patient_monitor',
     'Carescape B650 main board','warranty_defect',185000,'2026-06-05','2026-06-08',
     true,true,185000,0,'0_30','closed_credited','Full credit note received within SLA'),
    ('Suresh Nair','South - Kochi','RMA-2026-0432','Philips','imaging',
     'IntelliVue X3 display module','core_exchange',142000,'2026-06-10','2026-06-14',
     true,false,0,39,'31_60','awaiting_oem','Core dispatched, OEM yet to issue credit note'),
    ('Anil Reddy','South - Hyderabad','RMA-2026-0433','Fresenius','dialysis',
     '4008S dialysis pump head','warranty_defect',96000,'2026-05-02','2026-05-06',
     true,false,0,78,'61_90','overdue_no_credit','OEM confirmed receipt but credit stuck 78 days'),
    ('Vikram Singh','North - Delhi NCR','RMA-2026-0434','Draeger','ventilator',
     'Evita V300 turbine unit','doa_dead_on_arrival',310000,'2026-03-28','2026-04-02',
     false,false,0,112,'over_90','write_off_risk','DOA turbine lost in transit, no OEM acknowledgement — write-off risk'),
    ('Priya Menon','South - Bengaluru','RMA-2026-0435','Baxter','infusion_pump',
     'Sigma Spectrum pump mechanism','warranty_defect',54000,'2026-06-18','2026-06-20',
     true,true,54000,0,'0_30','closed_credited','Credit recovered in full'),
    ('Mohammed Irfan','West - Mumbai','RMA-2026-0436','Mindray','patient_monitor',
     'BeneVision N22 parameter module','wrong_part',72000,'2026-06-01','2026-06-05',
     true,false,0,48,'31_60','awaiting_oem','Wrong SpO2 module shipped by OEM, return credit pending'),
    ('Deepak Sharma','North - Chandigarh','RMA-2026-0437','Nihon Kohden','patient_monitor',
     'Life Scope G9 recorder board','core_exchange',128000,'2026-06-22','2026-06-25',
     false,false,0,24,'0_30','in_transit','Dispatched to OEM depot, in transit awaiting receipt'),
    ('Arjun Rao','West - Pune','RMA-2026-0438','Roche Diagnostics','lab_analyzer',
     'Cobas c311 photometer lamp assy','warranty_defect',88000,'2026-05-15','2026-05-18',
     true,true,79000,0,'0_30','closed_credited','Partial credit 79k of 88k accepted, closed'),
    ('Karthik Iyer','South - Chennai','RMA-2026-0439','Siemens Healthineers','imaging',
     'Mobilett Mira X-ray detector cable','recall_return',215000,'2026-04-20','2026-04-24',
     true,false,0,90,'61_90','overdue_no_credit','Recall return acknowledged, credit note overdue at 90 days'),
    ('Sanjay Gupta','East - Kolkata','RMA-2026-0440','BPL Medical','ventilator',
     'Ventura V30 blower motor','doa_dead_on_arrival',64000,'2026-06-12','2026-06-15',
     true,false,0,37,'31_60','awaiting_oem','DOA blower returned, OEM QA verification in progress'),
    ('Ramesh Babu','South - Hyderabad','RMA-2026-0441','Medtronic','infusion_pump',
     'SynchroMed pump control PCB','warranty_defect',118000,'2026-03-10','2026-03-13',
     false,false,0,130,'over_90','write_off_risk','OEM disputes warranty coverage, 130 days no credit — escalating'),
    ('Naveen Kumar','North - Delhi NCR','RMA-2026-0442','GE Healthcare','dialysis',
     'Aquaboss RO membrane module','core_exchange',45000,'2026-06-20','2026-06-23',
     true,true,45000,0,'0_30','closed_credited','Core exchange completed, credit applied'),
    ('Priya Menon','South - Bengaluru','RMA-2026-0443','Mindray','lab_analyzer',
     'BS-240 reagent probe assembly','wrong_part',39000,'2026-07-01',null,
     false,false,0,18,'0_30','awaiting_oem','Wrong probe received, RMA raised, awaiting OEM return label — not dispatched'),
    ('Mohammed Irfan','West - Mumbai','RMA-2026-0444','Draeger','patient_monitor',
     'Infinity M540 docking board','warranty_defect',97000,'2026-04-05','2026-04-09',
     true,false,0,101,'over_90','overdue_no_credit','Received by OEM but credit note stalled beyond 100 days')
  ) as q(eng, region, rma, oem, eqt, pd, rr, pv, rrd, dd, orc, cnr, ca, dp, ab, rv, nt);

  -- CAPA seed — attach to at-risk / overdue RMA cases via rma_code
  insert into public.core_rma_capa_actions_r3328 (
    rma_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    recovery_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.amt::numeric, q.nt
  from (values
    ('RMA-2026-0433','credit_note_missing','oem_process_backlog','escalate_to_oem_account_manager','in_progress','credit_at_risk','2026-07-25',null,96000,'Fresenius credit stuck 78 days — escalated to account manager'),
    ('RMA-2026-0434','logistics_lost_in_transit','courier_delay','engage_logistics_partner','escalated','full_write_off','2026-07-15',null,310000,'DOA turbine untraceable in transit — Blue Dart claim filed, write-off looming'),
    ('RMA-2026-0439','credit_note_missing','oem_process_backlog','raise_debit_note','open','credit_at_risk','2026-07-28',null,215000,'Siemens recall credit 90 days overdue — debit note to be raised'),
    ('RMA-2026-0441','write_off_pending','warranty_dispute','escalate_to_oem_account_manager','escalated','disputed','2026-07-10',null,118000,'Medtronic disputes warranty on PCB — legal and commercial escalation'),
    ('RMA-2026-0444','credit_note_missing','paperwork_incomplete','resubmit_documentation','verification_pending','credit_at_risk','2026-07-20',null,97000,'Draeger requires re-submission of proof-of-return docs'),
    ('RMA-2026-0436','wrong_part_returned','rma_code_error','resubmit_documentation','closed','credit_recovered','2026-06-30','2026-06-28',72000,'Mindray wrong-part RMA corrected, credit received and closed'),
    ('RMA-2026-0432','dispatch_delay','internal_tracking_gap','retrain_field_engineer','overdue','credit_at_risk','2026-07-05',null,142000,'Core exchange dispatch tracking gap — engineer retraining scheduled')
  ) as q(rma, fc, rc, ca, cst, fi, tcd, acd, amt, nt)
  join public.core_rma_r3328 e
    on e.organization_id = v_org_id and e.rma_code = q.rma;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) RMA verdict distribution
create or replace function public.founder_r3328_rma_verdict_rollup()
returns table(rma_verdict text, cases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.core_rma_r3328)
  select l.rma_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.core_rma_r3328 l
  group by l.rma_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_rma_verdict_rollup() from public, anon;
grant execute on function public.founder_r3328_rma_verdict_rollup() to authenticated;

-- 2) Region-level credit-recovery scorecard
create or replace function public.founder_r3328_region_scorecard()
returns table(
  region text,
  total_cases bigint,
  closed_credited bigint,
  awaiting bigint,
  overdue bigint,
  write_off_risk bigint,
  total_part_value_rupees numeric,
  total_credit_rupees numeric,
  recovery_pct numeric
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
    count(*) filter (where l.rma_verdict = 'closed_credited')::bigint,
    count(*) filter (where l.rma_verdict in ('awaiting_oem','in_transit'))::bigint,
    count(*) filter (where l.rma_verdict = 'overdue_no_credit')::bigint,
    count(*) filter (where l.rma_verdict = 'write_off_risk')::bigint,
    coalesce(sum(l.part_value_rupees),0)::numeric,
    coalesce(sum(l.credit_amount_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.credit_amount_rupees),0)::numeric / nullif(sum(l.part_value_rupees),0), 1)
  from public.core_rma_r3328 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_region_scorecard() from public, anon;
grant execute on function public.founder_r3328_region_scorecard() to authenticated;

-- 3) Equipment type × return reason matrix
create or replace function public.founder_r3328_equipment_reason_matrix()
returns table(equipment_type text, return_reason text, cases bigint, closed_credited bigint, avg_part_value_rupees numeric, total_credit_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.return_reason, count(*)::bigint,
    count(*) filter (where l.rma_verdict = 'closed_credited')::bigint,
    round(avg(l.part_value_rupees), 0),
    coalesce(sum(l.credit_amount_rupees),0)::numeric
  from public.core_rma_r3328 l
  group by l.equipment_type, l.return_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_equipment_reason_matrix() from public, anon;
grant execute on function public.founder_r3328_equipment_reason_matrix() to authenticated;

-- 4) Daily RMA-raised trend
create or replace function public.founder_r3328_daily_rma_trend()
returns table(rma_raised_date date, cases bigint, closed_credited bigint, overdue bigint, write_off_risk bigint, part_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rma_raised_date,
    count(*)::bigint,
    count(*) filter (where l.rma_verdict = 'closed_credited')::bigint,
    count(*) filter (where l.rma_verdict = 'overdue_no_credit')::bigint,
    count(*) filter (where l.rma_verdict = 'write_off_risk')::bigint,
    coalesce(sum(l.part_value_rupees),0)::numeric
  from public.core_rma_r3328 l
  group by l.rma_raised_date
  order by l.rma_raised_date desc;
end;
$$;

revoke execute on function public.founder_r3328_daily_rma_trend() from public, anon;
grant execute on function public.founder_r3328_daily_rma_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3328_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.core_rma_capa_actions_r3328 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_capa_status_board() from public, anon;
grant execute on function public.founder_r3328_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3328_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.core_rma_capa_actions_r3328)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.core_rma_capa_actions_r3328 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3328_root_cause_pareto() to authenticated;

-- 7) Financial-exposure digest (cost / risk digest by impact class)
create or replace function public.founder_r3328_financial_exposure_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric
  from public.core_rma_capa_actions_r3328 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3328_financial_exposure_digest() from public, anon;
grant execute on function public.founder_r3328_financial_exposure_digest() to authenticated;

-- 8) High-risk RMA queue (individual at-risk cases)
create or replace function public.founder_r3328_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  rma_code text,
  oem_vendor text,
  equipment_type text,
  return_reason text,
  rma_raised_date date,
  days_pending int,
  aging_bucket text,
  rma_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.rma_code, l.oem_vendor, l.equipment_type,
    l.return_reason, l.rma_raised_date, l.days_pending, l.aging_bucket,
    l.rma_verdict, l.notes
  from public.core_rma_r3328 l
  where l.rma_verdict in ('awaiting_oem','overdue_no_credit','write_off_risk')
     or l.aging_bucket in ('61_90','over_90')
     or (l.credit_note_received = false and l.oem_received_confirmed = true)
  order by l.days_pending desc, l.rma_raised_date desc;
end;
$$;

revoke execute on function public.founder_r3328_high_risk_queue() from public, anon;
grant execute on function public.founder_r3328_high_risk_queue() to authenticated;
