-- Round 3332: Engineer Preventive-Maintenance Checklist Completeness & Quality Audit
-- PM quality — engineer × equipment × checklist completion × measured-value capture × safety/cal recording × blank-entry detection × supervisor review × CAPA

-- =============================================================================
-- TABLE 1: pm_checklist_quality_r3332 — per-PM-job completeness & quality audit
-- =============================================================================
create table if not exists public.pm_checklist_quality_r3332 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  hospital_name text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','ventilator','imaging','dialysis','lab_analyzer','infusion_pump','anesthesia'
  )),
  pm_date date not null,
  checklist_items_total int not null,
  checklist_items_completed int not null,
  measured_values_captured boolean not null,
  electrical_safety_test_recorded boolean not null,
  calibration_verification_recorded boolean not null,
  photos_attached_count int not null,
  blank_or_default_entries int not null,
  time_on_site_minutes int not null,
  supervisor_review_status text not null check (supervisor_review_status in (
    'not_reviewed','approved','flagged_rework','rejected'
  )),
  quality_verdict text not null check (quality_verdict in (
    'thorough','acceptable','superficial','incomplete','falsification_suspected'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_checklist_quality_r3332 enable row level security;

create index if not exists idx_pm_checklist_quality_r3332_org on public.pm_checklist_quality_r3332(organization_id);
create index if not exists idx_pm_checklist_quality_r3332_date on public.pm_checklist_quality_r3332(pm_date);
create index if not exists idx_pm_checklist_quality_r3332_verdict on public.pm_checklist_quality_r3332(quality_verdict);

-- =============================================================================
-- TABLE 2: pm_checklist_quality_capa_actions_r3332 — rework / coaching / audit CAPA
-- =============================================================================
create table if not exists public.pm_checklist_quality_capa_actions_r3332 (
  id uuid primary key default gen_random_uuid(),
  pm_job_id uuid not null references public.pm_checklist_quality_r3332(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'incomplete_checklist','missing_measured_values','missing_safety_test','missing_calibration_record',
    'insufficient_photos','suspicious_blank_entries','short_time_on_site','falsification_suspected'
  )),
  root_cause text not null check (root_cause in (
    'time_pressure','inadequate_training','tools_unavailable','checklist_unclear',
    'negligence','equipment_access_issue','deliberate_shortcut','pending_investigation'
  )),
  action_type text not null check (action_type in (
    'rework_pm_visit','engineer_coaching','formal_warning','re_audit_scheduled',
    'process_update','tool_provisioning','retraining','none_required'
  )),
  action_status text not null check (action_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_impact text not null check (risk_impact in (
    'patient_safety_risk','compliance_finding','audit_readiness_gap','warranty_risk','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_checklist_quality_capa_actions_r3332 enable row level security;

create index if not exists idx_pm_checklist_capa_r3332_job on public.pm_checklist_quality_capa_actions_r3332(pm_job_id);
create index if not exists idx_pm_checklist_capa_r3332_status on public.pm_checklist_quality_capa_actions_r3332(action_status);

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

  -- 14 PM-quality audit rows
  insert into public.pm_checklist_quality_r3332 (
    organization_id, engineer_name, region, hospital_name, job_code, equipment_type,
    pm_date, checklist_items_total, checklist_items_completed,
    measured_values_captured, electrical_safety_test_recorded, calibration_verification_recorded,
    photos_attached_count, blank_or_default_entries, time_on_site_minutes,
    supervisor_review_status, quality_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.hosp, q.job, q.eqp,
    q.pmd::date, q.tot::int, q.comp::int,
    q.mvc, q.est, q.cvr,
    q.pho::int, q.blk::int, q.tos::int,
    q.srs, q.qv, q.nt
  from (values
    ('Rajesh Kumar','South','Apollo Chennai','PM-APL-CHN-2201','patient_monitor','2026-07-10',
     24,24,true,true,true,6,0,95,'approved','thorough','All 24 steps done, measured values and safety test logged with photos'),
    ('Amit Sharma','North','Fortis Gurgaon','PM-FRT-GGN-3310','ventilator','2026-07-10',
     30,28,true,true,true,4,1,80,'approved','acceptable','28 of 30 steps, 2 N/A steps documented, parameters captured'),
    ('Suresh Iyer','South','Manipal Bengaluru','PM-MNP-BLR-1120','dialysis','2026-07-09',
     26,19,false,true,false,1,5,40,'flagged_rework','superficial','Measured values blank, calibration record missing, only 40 min on site'),
    ('Vikram Singh','North','AIIMS Delhi','PM-AIM-DEL-4405','imaging','2026-07-09',
     22,22,true,true,true,8,0,120,'approved','thorough','CT PM complete with full parameter capture and tube-log photos'),
    ('Anand Raj','South','CMC Vellore','PM-CMC-VEL-2230','lab_analyzer','2026-07-08',
     28,21,true,false,true,2,3,55,'flagged_rework','superficial','Electrical safety test not recorded, 3 ditto entries flagged'),
    ('Prasad Rao','South','KIMS Hyderabad','PM-KIM-HYD-3345','infusion_pump','2026-07-08',
     18,18,true,true,true,5,0,60,'approved','thorough','Fleet infusion-pump PM, occlusion and flow values all captured'),
    ('Karthik Menon','South','Apollo Chennai','PM-APL-CHN-2202','anesthesia','2026-07-07',
     32,20,false,false,false,0,9,25,'rejected','falsification_suspected','All values identical to last quarter, 0 photos, 25 min on site — falsification suspected'),
    ('Deepak Verma','North','Fortis Gurgaon','PM-FRT-GGN-3311','patient_monitor','2026-07-07',
     24,23,true,true,true,3,1,70,'approved','acceptable','Solid PM, minor documentation gap on one alarm-test step'),
    ('Suresh Iyer','South','Manipal Bengaluru','PM-MNP-BLR-1121','ventilator','2026-07-06',
     30,24,false,true,true,2,4,50,'flagged_rework','superficial','Ventilator flow and pressure measured values not captured'),
    ('Prasad Rao','South','Rainbow Hospitals Hyderabad','PM-RBW-HYD-5501','patient_monitor','2026-07-06',
     24,24,true,true,true,7,0,85,'approved','thorough','NICU monitor PM complete, SpO2 and NIBP verification logged'),
    ('Amit Sharma','North','Medanta Gurgaon','PM-MDT-GGN-6620','imaging','2026-07-05',
     26,15,false,false,false,0,8,30,'rejected','incomplete','MRI PM abandoned midway, no measured values or safety tests recorded'),
    ('Anand Raj','South','Narayana Health Bengaluru','PM-NRY-BLR-7712','dialysis','2026-07-05',
     26,25,true,true,true,5,0,90,'approved','thorough','RO plant and dialysis machine PM with full water-quality capture'),
    ('Vikram Singh','North','AIIMS Delhi','PM-AIM-DEL-4406','lab_analyzer','2026-07-04',
     28,26,true,true,false,3,2,65,'not_reviewed','acceptable','Calibration verification certificate pending upload'),
    ('Karthik Menon','South','KIMS Hyderabad','PM-KIM-HYD-3346','infusion_pump','2026-07-04',
     18,12,false,true,false,1,4,35,'flagged_rework','superficial','Only 12 of 18 pumps done, batch marked complete incorrectly')
  ) as q(eng, reg, hosp, job, eqp, pmd, tot, comp, mvc, est, cvr, pho, blk, tos, srs, qv, nt);

  -- CAPA seed — attach to at-risk audits via job_code
  insert into public.pm_checklist_quality_capa_actions_r3332 (
    pm_job_id, finding_category, root_cause, action_type,
    action_status, risk_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.act,
    q.ast, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PM-MNP-BLR-1120','missing_measured_values','time_pressure','rework_pm_visit','in_progress','patient_safety_risk','2026-07-15',null,8000.00,'Re-PM booked — RO water-quality measured values must be captured'),
    ('PM-CMC-VEL-2230','missing_safety_test','inadequate_training','engineer_coaching','open','compliance_finding','2026-07-16',null,3000.00,'Coaching on electrical-safety-test protocol for bench lab analyzers'),
    ('PM-APL-CHN-2202','falsification_suspected','deliberate_shortcut','formal_warning','escalated','patient_safety_risk','2026-07-12',null,0.00,'Identical values to prior quarter — HR escalation and full re-audit ordered'),
    ('PM-MNP-BLR-1121','missing_measured_values','checklist_unclear','process_update','verification_pending','audit_readiness_gap','2026-07-14',null,2500.00,'Checklist updated to require flow and pressure values captured inline'),
    ('PM-MDT-GGN-6620','incomplete_checklist','equipment_access_issue','rework_pm_visit','open','patient_safety_risk','2026-07-13',null,15000.00,'MRI room access blocked mid-PM — reschedule with confirmed slot booking'),
    ('PM-KIM-HYD-3346','suspicious_blank_entries','negligence','re_audit_scheduled','overdue','compliance_finding','2026-07-08',null,4000.00,'Batch marked complete with 6 pumps untouched — re-audit overdue'),
    ('PM-AIM-DEL-4406','missing_calibration_record','tools_unavailable','tool_provisioning','closed','internal_only','2026-07-06','2026-07-07',1200.00,'Calibration certificate uploaded once reference gauge became available')
  ) as q(job, fc, rc, act, ast, ri, tcd, acd, cost, nt)
  join public.pm_checklist_quality_r3332 e
    on e.organization_id = v_org_id and e.job_code = q.job;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Quality verdict distribution
create or replace function public.founder_r3332_quality_verdict_rollup()
returns table(quality_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_checklist_quality_r3332)
  select l.quality_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pm_checklist_quality_r3332 l
  group by l.quality_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_quality_verdict_rollup() from public, anon;
grant execute on function public.founder_r3332_quality_verdict_rollup() to authenticated;

-- 2) Engineer-level quality scorecard
create or replace function public.founder_r3332_engineer_scorecard()
returns table(
  engineer_name text,
  total_audits bigint,
  thorough bigint,
  acceptable bigint,
  superficial bigint,
  incomplete_falsified bigint,
  missing_safety_test bigint,
  missing_calibration bigint,
  avg_completion_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.quality_verdict = 'thorough')::bigint,
    count(*) filter (where l.quality_verdict = 'acceptable')::bigint,
    count(*) filter (where l.quality_verdict = 'superficial')::bigint,
    count(*) filter (where l.quality_verdict in ('incomplete','falsification_suspected'))::bigint,
    count(*) filter (where l.electrical_safety_test_recorded = false)::bigint,
    count(*) filter (where l.calibration_verification_recorded = false)::bigint,
    round(avg(100.0 * l.checklist_items_completed / nullif(l.checklist_items_total,0)), 1)
  from public.pm_checklist_quality_r3332 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3332_engineer_scorecard() to authenticated;

-- 3) Equipment type × region matrix
create or replace function public.founder_r3332_equipment_region_matrix()
returns table(equipment_type text, region text, audits bigint, thorough bigint, avg_completion_pct numeric, avg_blank_entries numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.region, count(*)::bigint,
    count(*) filter (where l.quality_verdict = 'thorough')::bigint,
    round(avg(100.0 * l.checklist_items_completed / nullif(l.checklist_items_total,0)), 1),
    round(avg(l.blank_or_default_entries), 1)
  from public.pm_checklist_quality_r3332 l
  group by l.equipment_type, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_equipment_region_matrix() from public, anon;
grant execute on function public.founder_r3332_equipment_region_matrix() to authenticated;

-- 4) Daily PM-quality trend
create or replace function public.founder_r3332_daily_quality_trend()
returns table(pm_date date, audits bigint, thorough bigint, superficial_incomplete bigint, missing_safety_test bigint, missing_measured_values bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pm_date,
    count(*)::bigint,
    count(*) filter (where l.quality_verdict = 'thorough')::bigint,
    count(*) filter (where l.quality_verdict in ('superficial','incomplete','falsification_suspected'))::bigint,
    count(*) filter (where l.electrical_safety_test_recorded = false)::bigint,
    count(*) filter (where l.measured_values_captured = false)::bigint
  from public.pm_checklist_quality_r3332 l
  group by l.pm_date
  order by l.pm_date desc;
end;
$$;

revoke execute on function public.founder_r3332_daily_quality_trend() from public, anon;
grant execute on function public.founder_r3332_daily_quality_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3332_capa_status_board()
returns table(action_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.action_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.action_status in ('overdue','escalated'))::bigint
  from public.pm_checklist_quality_capa_actions_r3332 c
  group by c.action_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_capa_status_board() from public, anon;
grant execute on function public.founder_r3332_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3332_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_checklist_quality_capa_actions_r3332)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pm_checklist_quality_capa_actions_r3332 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3332_root_cause_pareto() to authenticated;

-- 7) Risk-impact digest
create or replace function public.founder_r3332_risk_impact_digest()
returns table(risk_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_impact, count(*)::bigint,
    count(*) filter (where c.action_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.pm_checklist_quality_capa_actions_r3332 c
  group by c.risk_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3332_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3332_risk_impact_digest() to authenticated;

-- 8) High-risk PM queue (individual concerns)
create or replace function public.founder_r3332_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  hospital_name text,
  job_code text,
  equipment_type text,
  pm_date date,
  quality_verdict text,
  supervisor_review_status text,
  completion_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.hospital_name, l.job_code, l.equipment_type, l.pm_date,
    l.quality_verdict, l.supervisor_review_status,
    round(100.0 * l.checklist_items_completed / nullif(l.checklist_items_total,0), 1),
    l.notes
  from public.pm_checklist_quality_r3332 l
  where l.quality_verdict in ('superficial','incomplete','falsification_suspected')
     or l.supervisor_review_status in ('flagged_rework','rejected')
     or l.measured_values_captured = false
     or l.electrical_safety_test_recorded = false
     or l.calibration_verification_recorded = false
     or l.blank_or_default_entries >= 3
  order by l.pm_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3332_high_risk_queue() from public, anon;
grant execute on function public.founder_r3332_high_risk_queue() to authenticated;
