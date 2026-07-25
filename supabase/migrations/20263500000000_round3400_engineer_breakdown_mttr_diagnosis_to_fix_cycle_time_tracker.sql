-- Round 3400: Engineer Field Breakdown MTTR / Diagnosis-to-Fix Cycle-Time Tracker
-- Breakdown cycle — equipment × severity × response × diagnosis × parts-wait × repair × total MTTR × first-visit-resolved × SLA × CAPA

-- =============================================================================
-- TABLE 1: breakdown_mttr_r3400 — per-breakdown cycle-time records
-- =============================================================================
create table if not exists public.breakdown_mttr_r3400 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null check (region in ('north','south','east','west','central')),
  equipment_type text not null check (equipment_type in (
    'patient_monitor','ventilator','infusion_pump','imaging','dialysis','lab_analyzer','defibrillator','ot_equipment'
  )),
  ticket_code text not null,
  breakdown_date date not null,
  severity text not null check (severity in (
    'critical_down','major','minor'
  )),
  response_time_hours numeric(7,2) not null,
  diagnosis_time_hours numeric(7,2) not null,
  parts_wait_hours numeric(7,2) not null,
  repair_time_hours numeric(7,2) not null,
  total_mttr_hours numeric(7,2) not null,
  parts_required boolean not null,
  first_visit_resolved boolean not null,
  sla_met boolean not null,
  mttr_verdict text not null check (mttr_verdict in (
    'within_sla','breached_sla','parts_delay','repeat_breakdown','escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.breakdown_mttr_r3400 enable row level security;

create index if not exists idx_breakdown_mttr_r3400_org on public.breakdown_mttr_r3400(organization_id);
create index if not exists idx_breakdown_mttr_r3400_date on public.breakdown_mttr_r3400(breakdown_date);
create index if not exists idx_breakdown_mttr_r3400_verdict on public.breakdown_mttr_r3400(mttr_verdict);

-- =============================================================================
-- TABLE 2: breakdown_mttr_capa_actions_r3400 — CAPA & process actions
-- =============================================================================
create table if not exists public.breakdown_mttr_capa_actions_r3400 (
  id uuid primary key default gen_random_uuid(),
  mttr_log_id uuid not null references public.breakdown_mttr_r3400(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'response_delay','diagnosis_delay','parts_delay','repair_delay',
    'repeat_breakdown','sla_breach','first_visit_miss','escalation_required'
  )),
  root_cause text not null check (root_cause in (
    'engineer_availability','skill_gap','parts_stockout','diagnostic_complexity',
    'oem_support_delay','travel_distance','wrong_part_carried','pending_investigation','recurring_defect'
  )),
  corrective_action text not null check (corrective_action in (
    'improve_routing','upskill_engineer','improve_parts_stock','remote_diagnostics',
    'escalate_oem','pre_stock_van','root_cause_fix','coach_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  sla_impact text not null check (sla_impact in (
    'penalty_incurred','relationship_risk','moderate','low','none','credit_note'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.breakdown_mttr_capa_actions_r3400 enable row level security;

create index if not exists idx_breakdown_mttr_capa_r3400_log on public.breakdown_mttr_capa_actions_r3400(mttr_log_id);
create index if not exists idx_breakdown_mttr_capa_r3400_status on public.breakdown_mttr_capa_actions_r3400(capa_status);

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

  insert into public.breakdown_mttr_r3400 (
    organization_id, engineer_name, hospital_name, region, equipment_type, ticket_code, breakdown_date,
    severity, response_time_hours, diagnosis_time_hours, parts_wait_hours, repair_time_hours,
    total_mttr_hours, parts_required, first_visit_resolved, sla_met, mttr_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.region, q.etype, q.ticket, q.bdate::date,
    q.sev, q.rt, q.dt, q.pw, q.rep,
    q.mttr, q.partsreq, q.ftr, q.slamet, q.verdict, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','south','patient_monitor','TKT-APL-9001','2026-07-03',
     'major',1.5,1.0,0.0,1.5,4.0,false,true,true,'within_sla','Monitor fixed first visit within SLA'),
    ('Anita Desai','Fortis Gurgaon','north','ventilator','TKT-FRT-9002','2026-07-02',
     'critical_down',0.8,1.5,0.0,2.0,4.3,false,true,true,'within_sla','Critical ventilator restored quickly, no parts'),
    ('Suresh Nair','Manipal Bengaluru','south','infusion_pump','TKT-MNP-9003','2026-07-02',
     'minor',3.0,0.5,24.0,1.0,28.5,true,false,false,'parts_delay','Infusion pump part backordered 24h — SLA breached'),
    ('Priya Menon','AIIMS Delhi','central','imaging','TKT-AIM-9004','2026-07-01',
     'critical_down',2.0,4.0,48.0,6.0,60.0,true,false,false,'breached_sla','CT tube issue, OEM part 48h — major SLA breach'),
    ('Vikram Rao','CMC Vellore','south','dialysis','TKT-CMC-9005','2026-07-01',
     'major',1.2,1.0,0.0,2.0,4.2,false,true,true,'within_sla','Dialysis machine fixed within SLA'),
    ('Deepa Iyer','KIMS Hyderabad','south','lab_analyzer','TKT-KIM-9006','2026-06-30',
     'major',2.5,3.0,12.0,2.0,19.5,true,false,false,'parts_delay','Analyzer reagent-probe part 12h wait'),
    ('Arjun Shah','Yashoda Hyderabad','south','defibrillator','TKT-YSH-9007','2026-06-30',
     'critical_down',1.0,0.5,0.0,1.0,2.5,false,true,true,'within_sla','Defibrillator battery swap fast resolution'),
    ('Ravi Kumar','Apollo Chennai','south','patient_monitor','TKT-APL-9008','2026-06-29',
     'minor',4.0,1.0,0.0,1.0,6.0,false,false,true,'repeat_breakdown','Same monitor 3rd breakdown this quarter — recurring defect'),
    ('Anita Desai','Fortis Gurgaon','north','ot_equipment','TKT-FRT-9009','2026-06-29',
     'major',5.0,2.0,0.0,2.0,9.0,false,false,false,'breached_sla','OT light delayed response due to engineer availability'),
    ('Suresh Nair','Manipal Bengaluru','south','ventilator','TKT-MNP-9010','2026-06-28',
     'critical_down',1.5,2.0,6.0,3.0,12.5,true,false,true,'within_sla','Ventilator valve replaced, part from local stock'),
    ('Priya Menon','AIIMS Delhi','central','dialysis','TKT-AIM-9011','2026-06-28',
     'major',2.0,1.5,0.0,2.0,5.5,false,true,true,'within_sla','Dialysis machine board reset within SLA'),
    ('Vikram Rao','CMC Vellore','south','imaging','TKT-CMC-9012','2026-06-27',
     'critical_down',3.0,5.0,72.0,8.0,88.0,true,false,false,'escalated','MRI cold-head, OEM part 72h — escalated to war-room'),
    ('Deepa Iyer','KIMS Hyderabad','south','infusion_pump','TKT-KIM-9013','2026-06-27',
     'minor',2.0,0.5,0.0,0.5,3.0,false,true,true,'within_sla','Infusion pump config fix first visit'),
    ('Arjun Shah','Kokilaben Mumbai','west','lab_analyzer','TKT-KKB-9014','2026-06-26',
     'major',6.0,4.0,36.0,3.0,49.0,true,false,false,'breached_sla','Analyzer wrong part carried, revisit + 36h wait')
  ) as q(eng, hosp, region, etype, ticket, bdate, sev, rt, dt, pw, rep, mttr, partsreq, ftr, slamet, verdict, nt);

  insert into public.breakdown_mttr_capa_actions_r3400 (
    mttr_log_id, finding_category, root_cause, corrective_action,
    capa_status, sla_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TKT-AIM-9004','parts_delay','oem_support_delay','escalate_oem','in_progress','penalty_incurred','2026-07-06',null,25000.00,'CT tube OEM lead-time reduction agreement in progress'),
    ('TKT-CMC-9012','escalation_required','oem_support_delay','pre_stock_van','escalated','relationship_risk','2026-07-04',null,0.00,'Pre-stock critical MRI spares regionally'),
    ('TKT-APL-9008','repeat_breakdown','recurring_defect','root_cause_fix','open','relationship_risk','2026-07-05',null,15000.00,'Monitor recurring fault — permanent board fix'),
    ('TKT-KKB-9014','first_visit_miss','wrong_part_carried','coach_engineer','verification_pending','credit_note','2026-07-05',null,0.00,'Improve pre-visit fault diagnosis to carry right part'),
    ('TKT-FRT-9009','response_delay','engineer_availability','improve_routing','overdue','moderate','2026-06-30',null,0.00,'North region routing/roster optimization past target'),
    ('TKT-MNP-9003','parts_delay','parts_stockout','improve_parts_stock','open','moderate','2026-07-07',null,8000.00,'Infusion pump fast-moving spare to reorder point'),
    ('TKT-KIM-9006','parts_delay','parts_stockout','improve_parts_stock','closed','low','2026-07-02','2026-06-30',6000.00,'Analyzer probe added to hub safety stock')
  ) as q(ticket, fc, rc, ca, cst, si, tcd, acd, cost, nt)
  join public.breakdown_mttr_r3400 e
    on e.organization_id = v_org_id and e.ticket_code = q.ticket;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3400_mttr_verdict_rollup()
returns table(mttr_verdict text, tickets bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.breakdown_mttr_r3400)
  select l.mttr_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.breakdown_mttr_r3400 l group by l.mttr_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_mttr_verdict_rollup() from public, anon;
grant execute on function public.founder_r3400_mttr_verdict_rollup() to authenticated;

create or replace function public.founder_r3400_engineer_scorecard()
returns table(
  engineer_name text, tickets bigint, avg_mttr_hours numeric, sla_met_count bigint,
  first_visit_resolved_count bigint, parts_delays bigint, breaches bigint, sla_met_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, count(*)::bigint,
    round(avg(l.total_mttr_hours), 1),
    count(*) filter (where l.sla_met = true)::bigint,
    count(*) filter (where l.first_visit_resolved = true)::bigint,
    count(*) filter (where l.mttr_verdict = 'parts_delay')::bigint,
    count(*) filter (where l.mttr_verdict in ('breached_sla','escalated'))::bigint,
    round(100.0 * count(*) filter (where l.sla_met = true)::numeric / nullif(count(*),0), 1)
  from public.breakdown_mttr_r3400 l group by l.engineer_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3400_engineer_scorecard() to authenticated;

create or replace function public.founder_r3400_equipment_severity_matrix()
returns table(equipment_type text, severity text, tickets bigint, avg_mttr_hours numeric, breaches bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.severity, count(*)::bigint,
    round(avg(l.total_mttr_hours), 1),
    count(*) filter (where l.sla_met = false)::bigint
  from public.breakdown_mttr_r3400 l group by l.equipment_type, l.severity order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_equipment_severity_matrix() from public, anon;
grant execute on function public.founder_r3400_equipment_severity_matrix() to authenticated;

create or replace function public.founder_r3400_daily_breakdown_trend()
returns table(breakdown_date date, tickets bigint, avg_mttr_hours numeric, sla_met bigint, breaches bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.breakdown_date, count(*)::bigint,
    round(avg(l.total_mttr_hours), 1),
    count(*) filter (where l.sla_met = true)::bigint,
    count(*) filter (where l.sla_met = false)::bigint
  from public.breakdown_mttr_r3400 l group by l.breakdown_date order by l.breakdown_date desc;
end;
$$;
revoke execute on function public.founder_r3400_daily_breakdown_trend() from public, anon;
grant execute on function public.founder_r3400_daily_breakdown_trend() to authenticated;

create or replace function public.founder_r3400_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.breakdown_mttr_capa_actions_r3400 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_capa_status_board() from public, anon;
grant execute on function public.founder_r3400_capa_status_board() to authenticated;

create or replace function public.founder_r3400_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.breakdown_mttr_capa_actions_r3400)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.breakdown_mttr_capa_actions_r3400 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3400_root_cause_pareto() to authenticated;

create or replace function public.founder_r3400_sla_impact_digest()
returns table(sla_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.sla_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.breakdown_mttr_capa_actions_r3400 c group by c.sla_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3400_sla_impact_digest() from public, anon;
grant execute on function public.founder_r3400_sla_impact_digest() to authenticated;

create or replace function public.founder_r3400_high_risk_queue()
returns table(
  hospital_name text, engineer_name text, ticket_code text, equipment_type text, severity text,
  breakdown_date date, total_mttr_hours numeric, parts_wait_hours numeric, mttr_verdict text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.ticket_code, l.equipment_type, l.severity,
    l.breakdown_date, l.total_mttr_hours, l.parts_wait_hours, l.mttr_verdict, l.notes
  from public.breakdown_mttr_r3400 l
  where l.mttr_verdict in ('breached_sla','parts_delay','repeat_breakdown','escalated')
     or l.sla_met = false
     or l.first_visit_resolved = false
  order by
    case l.mttr_verdict when 'escalated' then 0 when 'breached_sla' then 1 when 'repeat_breakdown' then 2 else 3 end,
    l.total_mttr_hours desc;
end;
$$;
revoke execute on function public.founder_r3400_high_risk_queue() from public, anon;
grant execute on function public.founder_r3400_high_risk_queue() to authenticated;
