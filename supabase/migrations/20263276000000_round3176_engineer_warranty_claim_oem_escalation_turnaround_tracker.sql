-- Round 3176: Engineer Warranty-Claim & OEM-Escalation Turnaround Tracker
-- Warranty/OEM claim log — equipment × OEM × claim type × raised/ack/resolved dates × TAT × SLA-met × escalation level × status + follow-up/CAPA actions

-- =============================================================================
-- TABLE 1: warranty_claim_r3176 — individual OEM warranty-claim records
-- =============================================================================
create table if not exists public.warranty_claim_r3176 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  equipment_name text not null,
  equipment_asset_tag text not null,
  oem_name text not null check (oem_name in (
    'ge_healthcare','philips_healthcare','siemens_healthineers','mindray','draeger',
    'getinge','nihon_kohden','skanray','bpl_medical','trivitron','medtronic',
    'fresenius_medical','canon_medical','carl_zeiss'
  )),
  claim_reference text not null,
  claim_type text not null check (claim_type in (
    'part_replacement','repair_service','full_unit_replacement',
    'recalibration','software_update','field_safety_recall'
  )),
  warranty_type text not null check (warranty_type in (
    'oem_standard_warranty','extended_warranty','comprehensive_amc',
    'non_comprehensive_amc','goodwill_out_of_warranty','dead_on_arrival'
  )),
  fault_category text not null check (fault_category in (
    'detector_failure','xray_tube_failure','probe_transducer_fault','power_supply_failure',
    'sensor_drift','board_pcb_failure','software_lockup','mechanical_wear',
    'battery_degraded','coolant_leak','calibration_out_of_spec','connectivity_fault'
  )),
  raised_date date not null,
  oem_acknowledged_date date,
  resolved_date date,
  tat_days int,
  sla_target_days int not null,
  sla_met boolean,
  escalation_level text not null check (escalation_level in (
    'none','l1_distributor','l2_oem_regional','l3_oem_national','l4_oem_principal','consumer_forum_legal'
  )),
  claim_status text not null check (claim_status in (
    'submitted','oem_acknowledged','parts_awaited','in_repair',
    'resolved_closed','rejected_by_oem','escalated','cancelled'
  )),
  claim_value_rupees numeric(12,2),
  created_at timestamptz not null default now()
);

alter table public.warranty_claim_r3176 enable row level security;

create index if not exists idx_warranty_claim_r3176_org on public.warranty_claim_r3176(organization_id);
create index if not exists idx_warranty_claim_r3176_raised on public.warranty_claim_r3176(raised_date);
create index if not exists idx_warranty_claim_r3176_status on public.warranty_claim_r3176(claim_status);

-- =============================================================================
-- TABLE 2: warranty_claim_capa_actions_r3176 — follow-up / CAPA actions
-- =============================================================================
create table if not exists public.warranty_claim_capa_actions_r3176 (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.warranty_claim_r3176(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'repeat_failure','sla_breach','oem_delay','parts_unavailable','warranty_dispute',
    'dead_on_arrival','recurring_fault','documentation_gap','out_of_warranty_dispute','installation_defect'
  )),
  root_cause text not null check (root_cause in (
    'oem_parts_backorder','oem_slow_response','distributor_bottleneck','warranty_terms_dispute',
    'manufacturing_defect','improper_installation','user_mishandling','environmental_damage',
    'power_surge_damage','pending_investigation','consumable_end_of_life'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_oem_parts','escalate_to_principal','invoke_penalty_clause','replace_under_warranty',
    'claim_goodwill_repair','file_consumer_complaint','retrain_biomedical_staff','install_voltage_stabilizer',
    'negotiate_amc_renewal','no_action_required','swap_loaner_unit'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','awaiting_oem','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','nabh_finding','iso_13485_deviation','patient_safety_alert',
    'none','internal_only','contract_penalty'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warranty_claim_capa_actions_r3176 enable row level security;

create index if not exists idx_warranty_capa_r3176_claim on public.warranty_claim_capa_actions_r3176(claim_id);
create index if not exists idx_warranty_capa_r3176_status on public.warranty_claim_capa_actions_r3176(capa_status);

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

  -- 14 warranty-claim rows across real Indian hospitals
  insert into public.warranty_claim_r3176 (
    organization_id, hospital_name, equipment_name, equipment_asset_tag, oem_name, claim_reference,
    claim_type, warranty_type, fault_category, raised_date, oem_acknowledged_date, resolved_date,
    tat_days, sla_target_days, sla_met, escalation_level, claim_status, claim_value_rupees
  )
  select v_org_id, q.hosp, q.eq, q.tag, q.oem, q.ref,
    q.ctype, q.wtype, q.fcat, q.rd::date, q.ackd::date, q.resd::date,
    q.tat, q.slatgt, q.slamet, q.esc, q.status, q.val
  from (values
    ('Apollo Hyderabad Jubilee Hills','CT Scanner Revolution CT','CT-APL-002','ge_healthcare','WCL-APL-3301',
     'part_replacement','comprehensive_amc','xray_tube_failure','2026-06-20','2026-06-22','2026-07-02',12,10,false,'l2_oem_regional','resolved_closed',850000.00),
    ('Apollo Hyderabad Jubilee Hills','MRI Signa Explorer','MRI-APL-005','ge_healthcare','WCL-APL-3302',
     'repair_service','oem_standard_warranty','coolant_leak','2026-07-01','2026-07-02',null,null,14,null,'l3_oem_national','in_repair',420000.00),
    ('Fortis Bannerghatta Bengaluru','Ventilator Evita V500','VNT-FRT-011','draeger','WCL-FRT-3303',
     'part_replacement','comprehensive_amc','board_pcb_failure','2026-06-25','2026-06-26','2026-06-30',5,7,true,'none','resolved_closed',65000.00),
    ('Fortis Bannerghatta Bengaluru','Patient Monitor MX550','MON-FRT-019','philips_healthcare','WCL-FRT-3304',
     'full_unit_replacement','dead_on_arrival','power_supply_failure','2026-07-03','2026-07-05',null,null,5,null,'l1_distributor','parts_awaited',180000.00),
    ('Manipal Whitefield Bengaluru','Ultrasound EPIQ 7','USG-MNP-008','philips_healthcare','WCL-MNP-3305',
     'repair_service','extended_warranty','probe_transducer_fault','2026-06-18','2026-06-19','2026-07-05',17,10,false,'l3_oem_national','escalated',240000.00),
    ('Manipal Whitefield Bengaluru','Dialysis Machine 4008S','DLY-MNP-014','fresenius_medical','WCL-MNP-3306',
     'part_replacement','comprehensive_amc','sensor_drift','2026-06-28','2026-06-29','2026-07-04',6,7,true,'none','resolved_closed',38000.00),
    ('AIIMS New Delhi Ansari Nagar','Cath Lab Azurion 7','CTH-AIM-001','philips_healthcare','WCL-AIM-3307',
     'repair_service','comprehensive_amc','detector_failure','2026-06-15','2026-06-17',null,null,12,null,'l4_oem_principal','escalated',1250000.00),
    ('AIIMS New Delhi Ansari Nagar','Anesthesia Perseus A500','ANS-AIM-023','draeger','WCL-AIM-3308',
     'recalibration','comprehensive_amc','calibration_out_of_spec','2026-06-30','2026-07-01','2026-07-03',3,5,true,'none','resolved_closed',22000.00),
    ('KIMS Secunderabad','Defibrillator TEC-8300','DEF-KIM-007','nihon_kohden','WCL-KIM-3309',
     'full_unit_replacement','oem_standard_warranty','battery_degraded','2026-06-22','2026-06-24','2026-07-06',14,10,false,'l2_oem_regional','resolved_closed',95000.00),
    ('KIMS Secunderabad','C-Arm Cios Alpha','ARM-KIM-016','siemens_healthineers','WCL-KIM-3310',
     'repair_service','non_comprehensive_amc','xray_tube_failure','2026-07-02',null,null,null,12,null,'l1_distributor','submitted',560000.00),
    ('Care Hospitals Banjara Hills','Infusion Pump BodyGuard','INF-CAR-031','bpl_medical','WCL-CAR-3311',
     'part_replacement','extended_warranty','mechanical_wear','2026-06-26','2026-06-27','2026-06-29',3,7,true,'none','resolved_closed',12000.00),
    ('Yashoda Somajiguda Hyderabad','Ventilator SV300','VNT-YSH-012','mindray','WCL-YSH-3312',
     'repair_service','comprehensive_amc','software_lockup','2026-06-29','2026-06-30',null,null,6,null,'l2_oem_regional','in_repair',45000.00),
    ('St John''s Bengaluru','X-Ray DigitalDiagnost','XRY-STJ-004','philips_healthcare','WCL-STJ-3313',
     'repair_service','oem_standard_warranty','connectivity_fault','2026-06-24','2026-06-25','2026-06-28',4,7,true,'none','resolved_closed',30000.00),
    ('Rainbow Children''s Hyderabad','Neonatal Incubator C2000','INC-RBW-009','draeger','WCL-RBW-3314',
     'full_unit_replacement','dead_on_arrival','power_supply_failure','2026-07-04','2026-07-05',null,null,5,null,'l3_oem_national','rejected_by_oem',210000.00)
  ) as q(hosp, eq, tag, oem, ref, ctype, wtype, fcat, rd, ackd, resd, tat, slatgt, slamet, esc, status, val);

  -- CAPA / follow-up seed — attach to specific claims by claim_reference
  insert into public.warranty_claim_capa_actions_r3176 (
    claim_id, raised_at, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.ra::timestamptz, q.fc, q.rc, q.ca,
    q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('WCL-APL-3301','2026-07-02 10:00:00+05:30','sla_breach','oem_parts_backorder','expedite_oem_parts',
     '2026-07-01','2026-07-02','closed','contract_penalty',25000.00,'CT tube TAT breached by 2 days; penalty clause invoked'),
    ('WCL-MNP-3305','2026-07-05 11:30:00+05:30','oem_delay','oem_slow_response','escalate_to_principal',
     '2026-07-06',null,'escalated','patient_safety_alert',40000.00,'Probe fault repeated; escalated to Philips principal'),
    ('WCL-AIM-3307','2026-06-18 09:15:00+05:30','repeat_failure','manufacturing_defect','replace_under_warranty',
     '2026-07-10',null,'awaiting_oem','cdsco_notifiable',0.00,'Detector board second failure in six months'),
    ('WCL-KIM-3309','2026-07-06 14:00:00+05:30','sla_breach','oem_slow_response','invoke_penalty_clause',
     '2026-07-05','2026-07-06','closed','contract_penalty',15000.00,'Defibrillator battery replacement delayed beyond SLA'),
    ('WCL-RBW-3314','2026-07-06 16:45:00+05:30','warranty_dispute','warranty_terms_dispute','file_consumer_complaint',
     '2026-07-12',null,'open','patient_safety_alert',30000.00,'OEM rejected DOA incubator claim; consumer forum route'),
    ('WCL-FRT-3304','2026-07-05 12:00:00+05:30','dead_on_arrival','manufacturing_defect','replace_under_warranty',
     '2026-07-08',null,'in_progress','iso_13485_deviation',0.00,'DOA patient monitor; replacement unit awaited from Philips')
  ) as q(ref_key, ra, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.warranty_claim_r3176 e
    on e.organization_id = v_org_id and e.claim_reference = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Claim status / verdict distribution
create or replace function public.founder_r3176_claim_status_rollup()
returns table(claim_status text, claims bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_claim_r3176)
  select l.claim_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.warranty_claim_r3176 l
  group by l.claim_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_claim_status_rollup() from public, anon;
grant execute on function public.founder_r3176_claim_status_rollup() to authenticated;

-- 2) Hospital / entity turnaround scorecard
create or replace function public.founder_r3176_hospital_scorecard()
returns table(
  hospital_name text,
  total_claims bigint,
  resolved bigint,
  escalated bigint,
  rejected bigint,
  sla_met_count bigint,
  sla_breached bigint,
  avg_tat_days numeric,
  sla_compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.claim_status = 'resolved_closed')::bigint,
    count(*) filter (where l.claim_status = 'escalated')::bigint,
    count(*) filter (where l.claim_status = 'rejected_by_oem')::bigint,
    count(*) filter (where l.sla_met is true)::bigint,
    count(*) filter (where l.sla_met is false)::bigint,
    round(avg(l.tat_days), 1),
    round(100.0 * count(*) filter (where l.sla_met is true)::numeric / nullif(count(*) filter (where l.sla_met is not null),0), 1)
  from public.warranty_claim_r3176 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3176_hospital_scorecard() to authenticated;

-- 3) OEM × claim-type turnaround matrix
create or replace function public.founder_r3176_oem_claim_matrix()
returns table(oem_name text, claim_type text, claims bigint, resolved bigint, avg_tat_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_name, l.claim_type, count(*)::bigint,
    count(*) filter (where l.claim_status = 'resolved_closed')::bigint,
    round(avg(l.tat_days), 1)
  from public.warranty_claim_r3176 l
  group by l.oem_name, l.claim_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_oem_claim_matrix() from public, anon;
grant execute on function public.founder_r3176_oem_claim_matrix() to authenticated;

-- 4) Claims-raised daily trend
create or replace function public.founder_r3176_raised_daily_trend()
returns table(raised_date date, claims_raised bigint, resolved bigint, escalated bigint, rejected bigint, avg_tat_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.raised_date,
    count(*)::bigint,
    count(*) filter (where l.claim_status = 'resolved_closed')::bigint,
    count(*) filter (where l.claim_status = 'escalated')::bigint,
    count(*) filter (where l.claim_status = 'rejected_by_oem')::bigint,
    round(avg(l.tat_days), 1)
  from public.warranty_claim_r3176 l
  group by l.raised_date
  order by l.raised_date desc;
end;
$$;

revoke execute on function public.founder_r3176_raised_daily_trend() from public, anon;
grant execute on function public.founder_r3176_raised_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3176_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.warranty_claim_capa_actions_r3176 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_capa_status_board() from public, anon;
grant execute on function public.founder_r3176_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3176_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warranty_claim_capa_actions_r3176)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.warranty_claim_capa_actions_r3176 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3176_root_cause_pareto() to authenticated;

-- 7) Regulatory / impact digest
create or replace function public.founder_r3176_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','awaiting_oem','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.warranty_claim_capa_actions_r3176 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3176_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3176_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority claim queue
create or replace function public.founder_r3176_priority_queue()
returns table(
  hospital_name text,
  equipment_name text,
  oem_name text,
  claim_reference text,
  raised_date date,
  claim_status text,
  escalation_level text,
  tat_days int,
  sla_met boolean,
  claim_value_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.equipment_name, l.oem_name, l.claim_reference, l.raised_date,
    l.claim_status, l.escalation_level, l.tat_days, l.sla_met, l.claim_value_rupees
  from public.warranty_claim_r3176 l
  where l.claim_status in ('submitted','oem_acknowledged','parts_awaited','in_repair','escalated','rejected_by_oem')
     or l.sla_met is false
     or l.escalation_level in ('l3_oem_national','l4_oem_principal','consumer_forum_legal')
  order by
    case l.escalation_level
      when 'consumer_forum_legal' then 0
      when 'l4_oem_principal' then 1
      when 'l3_oem_national' then 2
      when 'l2_oem_regional' then 3
      when 'l1_distributor' then 4
      else 5 end,
    l.raised_date desc;
end;
$$;

revoke execute on function public.founder_r3176_priority_queue() from public, anon;
grant execute on function public.founder_r3176_priority_queue() to authenticated;
