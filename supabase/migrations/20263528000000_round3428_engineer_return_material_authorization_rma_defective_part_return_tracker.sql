-- Round 3428: Engineer Return-Material-Authorization (RMA) / Defective-Part Return Tracker
-- Field-engineer RMA / defective-part return-to-supplier workflow — defect category × warranty × return status × turnaround × credit recovery × CAPA
-- NOTE: table names exceed 63 bytes; Postgres truncates them deterministically. Index names are short/explicit to avoid collisions.

-- =============================================================================
-- TABLE 1: engineer_return_material_authorization_rma_defective_part_r3428 — per-RMA defective-part return log
-- =============================================================================
create table if not exists public.engineer_return_material_authorization_rma_defective_part_r3428 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  rma_number text not null,
  part_name text not null,
  part_serial text,
  supplier_name text not null,
  defect_category text not null check (defect_category in (
    'dead_on_arrival','infant_mortality','wear_out','no_fault_found','physical_damage','counterfeit_suspected'
  )),
  warranty_status text not null check (warranty_status in (
    'in_warranty','out_of_warranty','goodwill'
  )),
  return_status text not null check (return_status in (
    'initiated','picked_up','in_transit','received','credited','replaced','rejected'
  )),
  raised_date date not null,
  closed_date date,
  credit_amount_rupees numeric(12,2),
  turnaround_days int,
  escalated boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_return_material_authorization_rma_defective_part_r3428 enable row level security;

create index if not exists idx_eng_rma_dpr_r3428_org on public.engineer_return_material_authorization_rma_defective_part_r3428(organization_id);
create index if not exists idx_eng_rma_dpr_r3428_raised on public.engineer_return_material_authorization_rma_defective_part_r3428(raised_date);
create index if not exists idx_eng_rma_dpr_r3428_status on public.engineer_return_material_authorization_rma_defective_part_r3428(return_status);

-- =============================================================================
-- TABLE 2: engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 — CAPA & supplier-quality actions
-- =============================================================================
create table if not exists public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 (
  id uuid primary key default gen_random_uuid(),
  rma_id uuid not null references public.engineer_return_material_authorization_rma_defective_part_r3428(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'supplier_quality_escape','no_fault_found_high','counterfeit_confirmed','warranty_claim_rejected',
    'credit_delay','repeat_failure_same_part','transit_damage','documentation_incomplete',
    'aging_rma_unclosed','wrong_part_shipped'
  )),
  root_cause text not null check (root_cause in (
    'supplier_process_defect','component_wear_expected','handling_damage_in_field','misdiagnosis_by_engineer',
    'counterfeit_grey_market','inadequate_esd_control','packaging_inadequate','supplier_credit_dispute',
    'pending_investigation','firmware_incompatibility'
  )),
  corrective_action text not null check (corrective_action in (
    'supplier_capa_requested','switch_alternate_vendor','engineer_diagnostic_retraining','improve_esd_handling',
    'upgrade_transit_packaging','escalate_credit_recovery','blacklist_counterfeit_source','tighten_incoming_inspection',
    'update_service_documentation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_field_safety','supplier_sla_breach','warranty_contract_dispute','iso_13485_deviation','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 enable row level security;

create index if not exists idx_eng_rma_dpr_capa_r3428_rma on public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428(rma_id);
create index if not exists idx_eng_rma_dpr_capa_r3428_status on public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428(capa_status);

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

  -- 16 RMA rows
  insert into public.engineer_return_material_authorization_rma_defective_part_r3428 (
    organization_id, engineer_name, rma_number, part_name, part_serial, supplier_name,
    defect_category, warranty_status, return_status, raised_date, closed_date,
    credit_amount_rupees, turnaround_days, escalated, notes
  )
  select v_org_id, q.eng, q.rma, q.part, q.serial, q.supp,
    q.defcat, q.warr, q.retst, q.rdate::date, q.cdate::date,
    q.credit, q.tdays, q.esc, q.nt
  from (values
    ('Sunil Menon','RMA-3428-001','ECG Module Board','ECGM-8842-A','GE Healthcare India',
     'dead_on_arrival','in_warranty','credited','2026-06-02','2026-06-14',48000.00,12,false,
     'DOA ECG acquisition board swapped under warranty; supplier credit note issued'),
    ('Sunil Menon','RMA-3428-002','SpO2 Sensor Cable','SPO2-1120-C','Masimo India',
     'infant_mortality','in_warranty','replaced','2026-06-05','2026-06-16',0.00,11,false,
     'Sensor cable failed within 30 days; free-of-charge replacement by supplier'),
    ('Anita Rao','RMA-3428-003','Ventilator Turbine','VTRB-5567','Hamilton Medical',
     'wear_out','out_of_warranty','rejected','2026-05-28','2026-06-10',0.00,13,false,
     'Turbine wear-out beyond warranty; claim rejected, chargeable repair advised'),
    ('Anita Rao','RMA-3428-004','Defib Battery Pack','DFBP-2299','Zoll India',
     'wear_out','goodwill','credited','2026-06-08','2026-06-20',6500.00,12,false,
     'Aged defib battery pack; supplier goodwill partial credit approved'),
    ('Ravi Teja','RMA-3428-005','Infusion Pump PCB','IPCB-7741','B. Braun India',
     'counterfeit_suspected','in_warranty','in_transit','2026-06-18',null,null,null,true,
     'Suspected counterfeit control PCB; returned to supplier for authentication'),
    ('Ravi Teja','RMA-3428-006','CT Detector Module','CTDM-0091','Siemens Healthineers',
     'dead_on_arrival','in_warranty','received','2026-06-20',null,null,null,true,
     'High-value DOA detector module received by supplier; credit note pending'),
    ('Priya Nair','RMA-3428-007','Ultrasound Probe L12','USPL-3345','Philips India',
     'physical_damage','out_of_warranty','rejected','2026-05-30','2026-06-12',0.00,13,false,
     'Transducer lens cracked in field; physical damage not covered'),
    ('Priya Nair','RMA-3428-008','Dialysis Blood Pump','DBPM-6678','Fresenius India',
     'no_fault_found','in_warranty','rejected','2026-06-10','2026-06-25',0.00,15,false,
     'Returned as faulty but no-fault-found on supplier bench; restocking advised'),
    ('Karthik Iyer','RMA-3428-009','Anesthesia Vaporizer','ANVP-4412','Drager India',
     'infant_mortality','in_warranty','credited','2026-06-01','2026-06-09',72000.00,8,false,
     'Early-life vaporizer failure; full credit issued promptly'),
    ('Karthik Iyer','RMA-3428-010','Patient Monitor Board','PMB-9987','Mindray India',
     'dead_on_arrival','in_warranty','picked_up','2026-06-22',null,null,null,false,
     'DOA patient-monitor mainboard picked up by supplier courier'),
    ('Deepak Shetty','RMA-3428-011','X-ray Tube Assembly','XTUB-1123','Canon Medical',
     'wear_out','out_of_warranty','rejected','2026-05-25','2026-06-08',0.00,14,true,
     'High-value tube wear-out; warranty rejected, escalated for goodwill review'),
    ('Deepak Shetty','RMA-3428-012','Syringe Pump Motor','SPMT-3390','BD India',
     'infant_mortality','in_warranty','credited','2026-06-12','2026-06-19',9500.00,7,false,
     'Pump motor failed early; credited quickly by supplier'),
    ('Meera Joshi','RMA-3428-013','C-arm Image Intensifier','CAII-5501','Ziehm Imaging',
     'counterfeit_suspected','out_of_warranty','initiated','2026-06-24',null,null,null,true,
     'Grey-market image-intensifier tube suspected counterfeit; RMA initiated with distributor'),
    ('Meera Joshi','RMA-3428-014','Endoscope Light Guide','ENLG-8834','Olympus India',
     'physical_damage','goodwill','replaced','2026-06-03','2026-06-15',0.00,12,false,
     'Light-guide bundle damage; goodwill replacement approved by supplier'),
    ('Sunil Menon','RMA-3428-015','Ventilator Flow Sensor','VFLS-2276','Hamilton Medical',
     'wear_out','in_warranty','credited','2026-06-14','2026-06-27',14500.00,13,false,
     'Flow-sensor drift within warranty; credit note received'),
    ('Anita Rao','RMA-3428-016','Autoclave Control PCB','ACPCB-7712','Getinge India',
     'no_fault_found','out_of_warranty','rejected','2026-05-27','2026-06-11',0.00,15,false,
     'No-fault-found on autoclave PCB; returned uncredited, chargeable diagnosis')
  ) as q(eng, rma, part, serial, supp, defcat, warr, retst, rdate, cdate, credit, tdays, esc, nt);

  -- CAPA seed — attach to specific RMAs by rma_number
  insert into public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 (
    rma_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RMA-3428-005','counterfeit_confirmed','counterfeit_grey_market','blacklist_counterfeit_source','escalated','cdsco_field_safety','2026-07-12',null,85000.00,'Counterfeit control PCB confirmed on authentication; grey-market source blacklisted'),
    ('RMA-3428-008','no_fault_found_high','misdiagnosis_by_engineer','engineer_diagnostic_retraining','in_progress','internal_only','2026-07-08',null,3000.00,'Recurring field misdiagnosis; blood-pump diagnostic retraining assigned'),
    ('RMA-3428-011','warranty_claim_rejected','supplier_credit_dispute','escalate_credit_recovery','escalated','warranty_contract_dispute','2026-07-15',null,240000.00,'High-value tube claim rejected; escalating goodwill/credit recovery with Canon'),
    ('RMA-3428-007','transit_damage','packaging_inadequate','upgrade_transit_packaging','closed','internal_only','2026-06-20','2026-06-18',5500.00,'Probe damage during return transit; foam-lined return cases rolled out'),
    ('RMA-3428-013','counterfeit_confirmed','counterfeit_grey_market','switch_alternate_vendor','open','cdsco_field_safety','2026-07-18',null,120000.00,'Grey-market II tube; procurement switched to authorized distributor'),
    ('RMA-3428-006','credit_delay','supplier_credit_dispute','escalate_credit_recovery','overdue','supplier_sla_breach','2026-07-05',null,180000.00,'Credit note overdue on high-value CT detector; SLA breach with Siemens'),
    ('RMA-3428-016','no_fault_found_high','inadequate_esd_control','improve_esd_handling','verification_pending','internal_only','2026-07-06',null,2500.00,'Repeat no-fault-found PCBs; ESD-handling audit at workshop bench'),
    ('RMA-3428-003','repeat_failure_same_part','component_wear_expected','update_service_documentation','closed','internal_only','2026-06-18','2026-06-15',4000.00,'Wear-out expected at end-of-life; PM interval and service docs updated')
  ) as q(rma, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.engineer_return_material_authorization_rma_defective_part_r3428 e
    on e.organization_id = v_org_id and e.rma_number = q.rma;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Return-status distribution
create or replace function public.founder_r3428_return_status_rollup()
returns table(return_status text, rmas bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_return_material_authorization_rma_defective_part_r3428)
  select l.return_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  group by l.return_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3428_return_status_rollup() from public, anon;
grant execute on function public.founder_r3428_return_status_rollup() to authenticated;

-- 2) Supplier scorecard
create or replace function public.founder_r3428_supplier_scorecard()
returns table(
  supplier_name text,
  total_rmas bigint,
  credited bigint,
  rejected bigint,
  replaced bigint,
  no_fault_found bigint,
  total_credit_rupees numeric,
  avg_turnaround_days numeric,
  credit_recovery_pct numeric
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
    count(*) filter (where l.return_status = 'credited')::bigint,
    count(*) filter (where l.return_status = 'rejected')::bigint,
    count(*) filter (where l.return_status = 'replaced')::bigint,
    count(*) filter (where l.defect_category = 'no_fault_found')::bigint,
    coalesce(sum(l.credit_amount_rupees),0)::numeric,
    round(avg(l.turnaround_days)::numeric, 1),
    round(100.0 * count(*) filter (where l.return_status = 'credited')::numeric / nullif(count(*),0), 1)
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  group by l.supplier_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3428_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3428_supplier_scorecard() to authenticated;

-- 3) Defect-category × warranty-status matrix
create or replace function public.founder_r3428_defect_warranty_matrix()
returns table(
  defect_category text,
  warranty_status text,
  rmas bigint,
  credited bigint,
  rejected bigint,
  avg_credit_rupees numeric,
  avg_turnaround_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.defect_category, l.warranty_status, count(*)::bigint,
    count(*) filter (where l.return_status = 'credited')::bigint,
    count(*) filter (where l.return_status = 'rejected')::bigint,
    round(avg(l.credit_amount_rupees)::numeric, 2),
    round(avg(l.turnaround_days)::numeric, 1)
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  group by l.defect_category, l.warranty_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3428_defect_warranty_matrix() from public, anon;
grant execute on function public.founder_r3428_defect_warranty_matrix() to authenticated;

-- 4) Monthly RMA trend
create or replace function public.founder_r3428_monthly_rma_trend()
returns table(
  month text,
  rmas bigint,
  credited bigint,
  rejected bigint,
  replaced bigint,
  avg_turnaround_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.raised_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.return_status = 'credited')::bigint,
    count(*) filter (where l.return_status = 'rejected')::bigint,
    count(*) filter (where l.return_status = 'replaced')::bigint,
    round(avg(l.turnaround_days)::numeric, 1)
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  group by to_char(l.raised_date, 'YYYY-MM')
  order by to_char(l.raised_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3428_monthly_rma_trend() from public, anon;
grant execute on function public.founder_r3428_monthly_rma_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3428_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3428_capa_status_board() from public, anon;
grant execute on function public.founder_r3428_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3428_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_return_material_authorization_rma_defective_part_capa_actions_r3428 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3428_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3428_root_cause_pareto() to authenticated;

-- 7) Financial-impact / credit-recovery digest (by warranty status)
create or replace function public.founder_r3428_credit_recovery_digest()
returns table(
  warranty_status text,
  rmas bigint,
  credited_count bigint,
  total_credit_rupees numeric,
  avg_credit_rupees numeric,
  pending_credit bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warranty_status,
    count(*)::bigint,
    count(*) filter (where l.return_status = 'credited')::bigint,
    coalesce(sum(l.credit_amount_rupees),0)::numeric,
    round(avg(l.credit_amount_rupees) filter (where l.return_status = 'credited')::numeric, 2),
    count(*) filter (where l.return_status in ('initiated','picked_up','in_transit','received'))::bigint
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  group by l.warranty_status
  order by coalesce(sum(l.credit_amount_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3428_credit_recovery_digest() from public, anon;
grant execute on function public.founder_r3428_credit_recovery_digest() to authenticated;

-- 8) High-risk RMA queue (aging / open / rejected / high-value / escalated / counterfeit)
create or replace function public.founder_r3428_high_risk_queue()
returns table(
  engineer_name text,
  rma_number text,
  part_name text,
  supplier_name text,
  defect_category text,
  warranty_status text,
  return_status text,
  raised_date date,
  credit_amount_rupees numeric,
  escalated text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.rma_number, l.part_name, l.supplier_name,
    l.defect_category, l.warranty_status, l.return_status, l.raised_date,
    l.credit_amount_rupees,
    case when l.escalated then 'yes' else 'no' end,
    l.notes
  from public.engineer_return_material_authorization_rma_defective_part_r3428 l
  where l.escalated = true
     or l.defect_category = 'counterfeit_suspected'
     or l.return_status = 'rejected'
     or l.return_status in ('initiated','picked_up','in_transit','received')
     or coalesce(l.turnaround_days,0) >= 14
     or coalesce(l.credit_amount_rupees,0) >= 50000
  order by l.raised_date desc, l.supplier_name;
end;
$$;

revoke execute on function public.founder_r3428_high_risk_queue() from public, anon;
grant execute on function public.founder_r3428_high_risk_queue() to authenticated;
