-- Round 3460: Engineer Installation Lead-Time / Cycle-Time Milestone Tracker
-- Installation delivery ops — project x milestone (PO -> go-live) x planned/actual/variance days x
-- milestone status x bottleneck x cycle-time trend x CAPA closure

-- =============================================================================
-- TABLE 1: install_leadtime_cycle_r3460 — per-project milestone lead-time / cycle-time facts
-- =============================================================================
create table if not exists public.install_leadtime_cycle_r3460 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  project_code text not null,
  device_model text not null,
  milestone text not null check (milestone in (
    'po_received','site_survey','dispatch','delivery','installation','commissioning','handover','go_live'
  )),
  planned_days int not null,
  actual_days int,
  variance_days int,
  milestone_status text not null check (milestone_status in (
    'on_track','at_risk','delayed','completed','blocked'
  )),
  bottleneck text not null check (bottleneck in (
    'site_readiness','logistics','customs','manpower','parts','customer_signoff','none'
  )),
  planned_date date not null,
  actual_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.install_leadtime_cycle_r3460 enable row level security;

create index if not exists idx_install_leadtime_cycle_r3460_org on public.install_leadtime_cycle_r3460(organization_id);
create index if not exists idx_install_leadtime_cycle_r3460_ms on public.install_leadtime_cycle_r3460(milestone);
create index if not exists idx_install_leadtime_cycle_r3460_status on public.install_leadtime_cycle_r3460(milestone_status);

-- =============================================================================
-- TABLE 2: install_leadtime_cycle_capa_actions_r3460 — CAPA & schedule-recovery actions
-- =============================================================================
create table if not exists public.install_leadtime_cycle_capa_actions_r3460 (
  id uuid primary key default gen_random_uuid(),
  install_ref_id uuid not null references public.install_leadtime_cycle_r3460(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'milestone_slip','lead_time_overrun','site_not_ready','logistics_delay','customs_hold',
    'manpower_shortage','parts_shortage','signoff_delay','commissioning_defect','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'site_civil_incomplete','customer_delay','vendor_logistics','customs_clearance','manpower_unavailable',
    'spare_parts_backorder','oem_dependency','scope_change','weather_disruption','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_logistics','deploy_extra_manpower','pre_stage_spares','escalate_customs','joint_site_readiness_review',
    'revise_project_plan','oem_escalation','customer_signoff_pushdrive','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  delay_impact text not null check (delay_impact in (
    'critical_path_slip','minor_slip','sla_penalty','revenue_deferral','none','cost_overrun'
  )),
  added_delay_days numeric(6,1),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.install_leadtime_cycle_capa_actions_r3460 enable row level security;

create index if not exists idx_install_leadtime_cycle_capa_r3460_ref on public.install_leadtime_cycle_capa_actions_r3460(install_ref_id);
create index if not exists idx_install_leadtime_cycle_capa_r3460_status on public.install_leadtime_cycle_capa_actions_r3460(capa_status);

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

  -- 16 project milestone rows
  insert into public.install_leadtime_cycle_r3460 (
    organization_id, engineer_name, hospital_name, project_code, device_model, milestone,
    planned_days, actual_days, variance_days, milestone_status, bottleneck,
    planned_date, actual_date, notes
  )
  select v_org_id, q.eng, q.hosp, q.pcode, q.model, q.ms,
    q.pdays, q.adays, q.vdays, q.mstat, q.bneck,
    q.pdate::date, q.adate::date, q.nt
  from (values
    ('Ramesh Kumar','Apollo Chennai','INST-APL-3401','GE Vivid E95','go_live',
     45,44,-1,'completed','none','2026-05-10','2026-05-09','Cardiac ultrasound go-live one day ahead of plan'),
    ('Anil Sharma','Fortis Gurgaon','INST-FRT-3402','Siemens Cios Alpha','commissioning',
     60,68,8,'delayed','site_readiness','2026-06-15','2026-06-23','OT civil works pushed commissioning 8 days'),
    ('Priya Nair','Manipal Bengaluru','INST-MNP-3403','Philips Azurion 7','installation',
     50,null,null,'at_risk','customs','2026-07-20',null,'Cath lab shipment held at Chennai customs'),
    ('Suresh Reddy','AIIMS Delhi','INST-AIM-3404','GE Optima CT540','delivery',
     30,42,12,'delayed','logistics','2026-06-28','2026-07-10','CT gantry transport delayed 12 days on road permits'),
    ('Vikram Singh','CMC Vellore','INST-CMC-3405','Drager Fabius','handover',
     40,39,-1,'completed','none','2026-05-22','2026-05-21','Anesthesia workstation handover complete'),
    ('Deepa Menon','KIMS Hyderabad','INST-KIM-3406','Mindray Resona 7','site_survey',
     15,16,1,'on_track','none','2026-07-05','2026-07-06','Radiology site survey done, minor slip'),
    ('Karthik Iyer','Yashoda Hyderabad','INST-YSH-3407','Siemens Magnetom Sola','po_received',
     5,5,0,'on_track','none','2026-07-12','2026-07-12','MRI PO acknowledged, project kickoff'),
    ('Manoj Gupta','Kokilaben Mumbai','INST-KKB-3408','Philips Ingenia','installation',
     55,71,16,'blocked','manpower','2026-06-10','2026-07-01','MRI install blocked — rigging crew unavailable'),
    ('Ramesh Kumar','Apollo Chennai','INST-APL-3409','Hologic Selenia','commissioning',
     48,52,4,'delayed','parts','2026-06-20','2026-06-24','Mammo detector spare backordered'),
    ('Priya Nair','Narayana Bengaluru','INST-NAR-3410','Fujifilm FDR','go_live',
     42,40,-2,'completed','none','2026-05-30','2026-05-28','DR system go-live ahead of schedule'),
    ('Anil Sharma','Medanta Gurgaon','INST-MED-3411','GE Discovery IQ','dispatch',
     20,24,4,'delayed','logistics','2026-07-01','2026-07-05','PET-CT dispatch delayed at OEM warehouse'),
    ('Suresh Reddy','Care Hyderabad','INST-CAR-3412','Mindray BeneVision','installation',
     35,null,null,'at_risk','site_readiness','2026-07-22',null,'Central monitoring install pending ICU handover'),
    ('Vikram Singh','Rainbow Hyderabad','INST-RBW-3413','Drager Babyleo','commissioning',
     38,37,-1,'completed','none','2026-06-05','2026-06-04','NICU incubator commissioning complete'),
    ('Deepa Menon','Aster Kochi','INST-AST-3414','Canon Aquilion','handover',
     52,63,11,'delayed','customer_signoff','2026-06-18','2026-06-29','CT handover delayed awaiting biomedical signoff'),
    ('Karthik Iyer','SGPGI Lucknow','INST-SGP-3415','Siemens Artis','delivery',
     33,null,null,'blocked','customs','2026-07-25',null,'Cath lab blocked — customs documentation dispute'),
    ('Manoj Gupta','Amrita Kochi','INST-AMR-3416','Philips EPIQ','installation',
     46,49,3,'on_track','manpower','2026-07-08','2026-07-11','Ultrasound install progressing with contract labor')
  ) as q(eng, hosp, pcode, model, ms, pdays, adays, vdays, mstat, bneck, pdate, adate, nt);

  -- CAPA seed — attach to specific projects via project_code
  insert into public.install_leadtime_cycle_capa_actions_r3460 (
    install_ref_id, finding_category, root_cause, corrective_action,
    capa_status, delay_impact, added_delay_days, estimated_cost_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.di, q.adl, q.cost, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('INST-FRT-3402','site_not_ready','site_civil_incomplete','joint_site_readiness_review','in_progress','critical_path_slip',8,25000.00,'Anil Sharma','2026-07-05',null,'OT civil works being expedited with hospital PWD'),
    ('INST-MNP-3403','customs_hold','customs_clearance','escalate_customs','escalated','critical_path_slip',10,40000.00,'Priya Nair','2026-07-28',null,'Cath lab held — CHA escalation raised'),
    ('INST-AIM-3404','logistics_delay','vendor_logistics','expedite_logistics','closed','minor_slip',12,18000.00,'Suresh Reddy','2026-07-08','2026-07-10','CT gantry delivered after road-permit resolution'),
    ('INST-KKB-3408','manpower_shortage','manpower_unavailable','deploy_extra_manpower','open','sla_penalty',16,60000.00,'Manoj Gupta','2026-07-18',null,'Rigging crew being mobilized from Pune'),
    ('INST-APL-3409','parts_shortage','spare_parts_backorder','pre_stage_spares','verification_pending','cost_overrun',4,12000.00,'Ramesh Kumar','2026-06-30',null,'Mammo detector spare received, awaiting install verify'),
    ('INST-AST-3414','signoff_delay','customer_delay','customer_signoff_pushdrive','overdue','revenue_deferral',11,0.00,'Deepa Menon','2026-06-25',null,'Biomedical signoff overdue — daily follow-up'),
    ('INST-SGP-3415','customs_hold','customs_clearance','oem_escalation','escalated','critical_path_slip',15,55000.00,'Karthik Iyer','2026-08-02',null,'Customs documentation dispute — OEM legal engaged'),
    ('INST-MED-3411','logistics_delay','vendor_logistics','revise_project_plan','closed','minor_slip',4,9000.00,'Anil Sharma','2026-07-10','2026-07-09','PET-CT dispatch replanned, back on track')
  ) as q(pcode, fc, rc, ca, cst, di, adl, cost, own, tcd, acd, nt)
  join public.install_leadtime_cycle_r3460 e
    on e.organization_id = v_org_id and e.project_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Milestone status distribution
create or replace function public.founder_r3460_milestone_status_rollup()
returns table(milestone_status text, projects bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.install_leadtime_cycle_r3460)
  select l.milestone_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.install_leadtime_cycle_r3460 l
  group by l.milestone_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_milestone_status_rollup() from public, anon;
grant execute on function public.founder_r3460_milestone_status_rollup() to authenticated;

-- 2) Milestone scorecard
create or replace function public.founder_r3460_milestone_scorecard()
returns table(
  milestone text,
  projects bigint,
  completed bigint,
  on_track bigint,
  delayed bigint,
  blocked bigint,
  avg_planned_days numeric,
  avg_actual_days numeric,
  avg_variance_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.milestone,
    count(*)::bigint,
    count(*) filter (where l.milestone_status = 'completed')::bigint,
    count(*) filter (where l.milestone_status = 'on_track')::bigint,
    count(*) filter (where l.milestone_status = 'delayed')::bigint,
    count(*) filter (where l.milestone_status = 'blocked')::bigint,
    round(avg(l.planned_days), 1),
    round(avg(l.actual_days), 1),
    round(avg(l.variance_days), 1)
  from public.install_leadtime_cycle_r3460 l
  group by l.milestone
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_milestone_scorecard() from public, anon;
grant execute on function public.founder_r3460_milestone_scorecard() to authenticated;

-- 3) Milestone × bottleneck matrix
create or replace function public.founder_r3460_milestone_bottleneck_matrix()
returns table(milestone text, bottleneck text, projects bigint, delayed bigint, avg_variance_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.milestone, l.bottleneck, count(*)::bigint,
    count(*) filter (where l.milestone_status in ('delayed','blocked'))::bigint,
    round(avg(l.variance_days), 1)
  from public.install_leadtime_cycle_r3460 l
  group by l.milestone, l.bottleneck
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_milestone_bottleneck_matrix() from public, anon;
grant execute on function public.founder_r3460_milestone_bottleneck_matrix() to authenticated;

-- 4) Monthly cycle-time trend
create or replace function public.founder_r3460_monthly_cycle_time_trend()
returns table(
  cycle_month text,
  projects bigint,
  avg_planned_days numeric,
  avg_actual_days numeric,
  avg_variance_days numeric,
  delayed bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.planned_date), 'YYYY-MM'),
    count(*)::bigint,
    round(avg(l.planned_days), 1),
    round(avg(l.actual_days), 1),
    round(avg(l.variance_days), 1),
    count(*) filter (where l.milestone_status in ('delayed','blocked'))::bigint
  from public.install_leadtime_cycle_r3460 l
  group by date_trunc('month', l.planned_date)
  order by date_trunc('month', l.planned_date) desc;
end;
$$;

revoke execute on function public.founder_r3460_monthly_cycle_time_trend() from public, anon;
grant execute on function public.founder_r3460_monthly_cycle_time_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3460_capa_status_board()
returns table(capa_status text, findings bigint, avg_added_delay_days numeric, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.added_delay_days), 1),
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.install_leadtime_cycle_capa_actions_r3460 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_capa_status_board() from public, anon;
grant execute on function public.founder_r3460_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3460_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_added_delay_days numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.install_leadtime_cycle_capa_actions_r3460)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.added_delay_days),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.install_leadtime_cycle_capa_actions_r3460 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3460_root_cause_pareto() to authenticated;

-- 7) Lead-time impact digest
create or replace function public.founder_r3460_lead_time_impact_digest()
returns table(delay_impact text, findings bigint, open_findings bigint, total_added_delay_days numeric, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.delay_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.added_delay_days),0)::numeric,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.install_leadtime_cycle_capa_actions_r3460 c
  group by c.delay_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3460_lead_time_impact_digest() from public, anon;
grant execute on function public.founder_r3460_lead_time_impact_digest() to authenticated;

-- 8) High-risk milestone queue (delayed / blocked / large-variance)
create or replace function public.founder_r3460_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  project_code text,
  device_model text,
  milestone text,
  milestone_status text,
  bottleneck text,
  planned_days int,
  actual_days int,
  variance_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.project_code, l.device_model, l.milestone,
    l.milestone_status, l.bottleneck, l.planned_days, l.actual_days, l.variance_days, l.notes
  from public.install_leadtime_cycle_r3460 l
  where l.milestone_status in ('at_risk','delayed','blocked')
     or l.variance_days >= 8
     or l.bottleneck in ('customs','manpower','site_readiness')
  order by l.variance_days desc nulls last, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3460_high_risk_queue() from public, anon;
grant execute on function public.founder_r3460_high_risk_queue() to authenticated;
