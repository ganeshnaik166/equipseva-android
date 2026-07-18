-- Round 3296: Engineer No-Fault-Found (NFF) & Misdiagnosis Return-Rate Tracker
-- Ops quality — nff_verdict × engineer scorecard × equipment/finding matrix × daily trend
--   × root-cause pareto × region waste-cost digest × CAPA coaching actions × high-risk queue

-- =============================================================================
-- TABLE 1: nff_return_r3296 — per-case NFF / misdiagnosis return records
-- =============================================================================
create table if not exists public.nff_return_r3296 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','infusion_pump','ventilator','imaging','dialysis','lab_analyzer','defibrillator'
  )),
  reported_fault text not null,
  workshop_finding text not null check (workshop_finding in (
    'confirmed_fault','no_fault_found','different_fault','user_error','intermittent_unconfirmed'
  )),
  part_replaced boolean not null default false,
  part_actually_faulty boolean not null default false,
  wasted_part_cost_rupees numeric(12,2),
  freight_cost_rupees numeric(12,2),
  repeat_dispatch_needed boolean not null default false,
  root_cause text not null check (root_cause in (
    'correct_diagnosis','insufficient_testing','misread_symptom','no_error_code_check','rushed_visit','customer_misreport'
  )),
  nff_verdict text not null check (nff_verdict in (
    'correct_call','nff_wasteful','misdiagnosis','user_education_needed'
  )),
  case_date date not null,
  case_logged_at timestamptz not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nff_return_r3296 enable row level security;

create index if not exists idx_nff_return_r3296_org on public.nff_return_r3296(organization_id);
create index if not exists idx_nff_return_r3296_date on public.nff_return_r3296(case_date);
create index if not exists idx_nff_return_r3296_verdict on public.nff_return_r3296(nff_verdict);

-- =============================================================================
-- TABLE 2: nff_return_capa_actions_r3296 — coaching / process CAPA findings
-- =============================================================================
create table if not exists public.nff_return_capa_actions_r3296 (
  id uuid primary key default gen_random_uuid(),
  case_log_id uuid not null references public.nff_return_r3296(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'nff_wasteful_dispatch','misdiagnosis_wrong_part','insufficient_diagnostics',
    'user_training_gap','repeat_dispatch','freight_waste','process_gap'
  )),
  coaching_action text not null check (coaching_action in (
    'diagnostic_checklist_training','error_code_reading_training','remote_triage_first',
    'peer_review_before_part_order','customer_education_call','tool_kit_upgrade',
    'shadow_senior_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  severity text not null check (severity in (
    'low','medium','high','critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  recoverable_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nff_return_capa_actions_r3296 enable row level security;

create index if not exists idx_nff_capa_r3296_log on public.nff_return_capa_actions_r3296(case_log_id);
create index if not exists idx_nff_capa_r3296_status on public.nff_return_capa_actions_r3296(capa_status);

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

  -- 14 NFF / misdiagnosis case rows
  insert into public.nff_return_r3296 (
    organization_id, engineer_name, region, job_code, equipment_type,
    reported_fault, workshop_finding, part_replaced, part_actually_faulty,
    wasted_part_cost_rupees, freight_cost_rupees, repeat_dispatch_needed,
    root_cause, nff_verdict, case_date, case_logged_at, notes
  )
  select v_org_id, q.eng, q.reg, q.jc, q.eqt,
    q.rf, q.wf, q.pr, q.paf,
    q.wpc, q.fc, q.rdn,
    q.rc, q.nv, q.cd::date, q.clg::timestamptz, q.nt
  from (values
    ('Ramesh Iyer','South','JC-CHN-4101','patient_monitor','No display / dead unit','confirmed_fault',true,true,
     8500.00,1200.00,false,'correct_diagnosis','correct_call','2026-07-02','2026-07-02 10:15:00+05:30','Power board confirmed faulty at workshop and replaced'),
    ('Suresh Nair','South','JC-BLR-4102','infusion_pump','Intermittent occlusion alarm','no_fault_found',true,false,
     6200.00,900.00,true,'insufficient_testing','nff_wasteful','2026-07-02','2026-07-02 11:40:00+05:30','No fault reproduced at workshop; occlusion sensor swapped needlessly'),
    ('Anil Kumar','North','JC-DEL-4103','ventilator','Low PEEP alarm','different_fault',true,false,
     15400.00,1800.00,true,'misread_symptom','misdiagnosis','2026-07-01','2026-07-01 09:20:00+05:30','Flow sensor replaced but actual fault was exhalation valve; repeat dispatch needed'),
    ('Priya Menon','South','JC-VEL-4104','defibrillator','Will not charge','user_error',false,false,
     0.00,800.00,false,'customer_misreport','user_education_needed','2026-07-01','2026-07-01 14:05:00+05:30','Unit left in ECG-only mode; staff retrained, no defect present'),
    ('Vikram Reddy','South','JC-HYD-4105','imaging','Random reboot','intermittent_unconfirmed',false,false,
     0.00,2500.00,true,'insufficient_testing','nff_wasteful','2026-06-30','2026-06-30 08:30:00+05:30','C-arm reboot not reproduced over 48h soak; freight wasted, revisit planned'),
    ('Rahul Deshpande','West','JC-MUM-4106','dialysis','Conductivity alarm','confirmed_fault',true,true,
     11200.00,1500.00,false,'correct_diagnosis','correct_call','2026-06-30','2026-06-30 12:10:00+05:30','Conductivity cell confirmed drifted; replaced and recalibrated'),
    ('Karthik Subramaniam','South','JC-CHN-4107','lab_analyzer','Sample probe jam','no_fault_found',true,false,
     4800.00,700.00,false,'no_error_code_check','nff_wasteful','2026-06-29','2026-06-29 10:50:00+05:30','Error log showed a simple clog; probe assembly replaced without reading codes'),
    ('Sandeep Verma','North','JC-DEL-4108','patient_monitor','SpO2 not reading','different_fault',true,false,
     5600.00,1100.00,true,'rushed_visit','misdiagnosis','2026-06-29','2026-06-29 15:30:00+05:30','SpO2 board swapped but real issue was the cable; second trip required'),
    ('Meena Krishnan','South','JC-BLR-4109','infusion_pump','Battery not holding','confirmed_fault',true,true,
     3200.00,600.00,false,'correct_diagnosis','correct_call','2026-06-28','2026-06-28 09:45:00+05:30','Battery pack confirmed degraded and replaced'),
    ('Arjun Pillai','South','JC-VEL-4110','ventilator','Circuit leak alarm','user_error',false,false,
     0.00,900.00,false,'customer_misreport','user_education_needed','2026-06-28','2026-06-28 13:20:00+05:30','Breathing circuit mis-assembled by ICU staff; correct assembly demonstrated'),
    ('Rohit Sharma','North','JC-GGN-4111','imaging','Image artifact','no_fault_found',true,false,
     22000.00,3200.00,true,'insufficient_testing','nff_wasteful','2026-06-27','2026-06-27 11:00:00+05:30','Detector board replaced but artifact was a calibration issue; high-value part wasted'),
    ('Deepak Rao','South','JC-HYD-4112','defibrillator','Fails self-test','confirmed_fault',true,true,
     9800.00,1300.00,false,'correct_diagnosis','correct_call','2026-06-27','2026-06-27 16:15:00+05:30','HV capacitor confirmed failed; replaced and self-test passed'),
    ('Ravi Shankar','West','JC-PUN-4113','dialysis','Occasional blood leak alarm','intermittent_unconfirmed',false,false,
     0.00,1400.00,false,'correct_diagnosis','correct_call','2026-06-26','2026-06-26 10:30:00+05:30','No fault found but engineer correctly documented and monitored instead of swapping parts'),
    ('Nikhil Joshi','North','JC-DEL-4114','lab_analyzer','Reagent temp error','different_fault',true,false,
     null,1000.00,true,'no_error_code_check','misdiagnosis','2026-06-26','2026-06-26 14:50:00+05:30','Peltier module replaced but fault was the ambient sensor; part cost pending from workshop')
  ) as q(eng, reg, jc, eqt, rf, wf, pr, paf, wpc, fc, rdn, rc, nv, cd, clg, nt);

  -- CAPA coaching / process seed — attach to wasteful & misdiagnosis cases via job_code
  insert into public.nff_return_capa_actions_r3296 (
    case_log_id, finding_category, coaching_action, capa_status, severity,
    target_closure_date, actual_closure_date, recoverable_cost_rupees, notes
  )
  select e.id, q.fc, q.ca, q.cst, q.sev,
    q.tcd::date, q.acd::date, q.rec, q.nt
  from (values
    ('JC-BLR-4102','nff_wasteful_dispatch','diagnostic_checklist_training','in_progress','medium','2026-07-10',null,6200.00,'Occlusion sensor swapped with no fault; engineer to complete diagnostic checklist training'),
    ('JC-DEL-4103','misdiagnosis_wrong_part','peer_review_before_part_order','open','high','2026-07-09',null,15400.00,'Flow sensor replaced for exhalation-valve fault; enforce peer review before high-value part order'),
    ('JC-HYD-4105','freight_waste','remote_triage_first','in_progress','medium','2026-07-08',null,2500.00,'C-arm reboot not reproduced; add 48h remote-log triage before dispatch'),
    ('JC-CHN-4107','insufficient_diagnostics','error_code_reading_training','closed','low','2026-07-05','2026-07-04',4800.00,'Probe replaced without reading error log; refresher completed and verified'),
    ('JC-DEL-4108','misdiagnosis_wrong_part','shadow_senior_engineer','verification_pending','high','2026-07-06',null,5600.00,'SpO2 board swapped for a cable fault; engineer to shadow senior on next 5 monitor calls'),
    ('JC-GGN-4111','nff_wasteful_dispatch','peer_review_before_part_order','escalated','critical','2026-07-04',null,22000.00,'High-value detector board replaced needlessly; escalated to service head for cost recovery'),
    ('JC-DEL-4114','misdiagnosis_wrong_part','error_code_reading_training','open','high','2026-07-12',null,7300.00,'Peltier module replaced for an ambient-sensor fault; error-code reading training assigned')
  ) as q(jc, fc, ca, cst, sev, tcd, acd, rec, nt)
  join public.nff_return_r3296 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) NFF verdict distribution
create or replace function public.founder_r3296_nff_verdict_rollup()
returns table(nff_verdict text, cases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nff_return_r3296)
  select l.nff_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nff_return_r3296 l
  group by l.nff_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3296_nff_verdict_rollup() from public, anon;
grant execute on function public.founder_r3296_nff_verdict_rollup() to authenticated;

-- 2) Engineer NFF scorecard
create or replace function public.founder_r3296_engineer_scorecard()
returns table(
  engineer_name text,
  total_cases bigint,
  correct_calls bigint,
  nff_wasteful bigint,
  misdiagnosis bigint,
  parts_replaced bigint,
  parts_not_faulty bigint,
  repeat_dispatches bigint,
  wasted_cost_rupees numeric,
  accuracy_pct numeric
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
    count(*) filter (where l.nff_verdict = 'correct_call')::bigint,
    count(*) filter (where l.nff_verdict = 'nff_wasteful')::bigint,
    count(*) filter (where l.nff_verdict = 'misdiagnosis')::bigint,
    count(*) filter (where l.part_replaced)::bigint,
    count(*) filter (where l.part_replaced and not l.part_actually_faulty)::bigint,
    count(*) filter (where l.repeat_dispatch_needed)::bigint,
    coalesce(sum(l.wasted_part_cost_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.nff_verdict = 'correct_call')::numeric / nullif(count(*),0), 1)
  from public.nff_return_r3296 l
  group by l.engineer_name
  order by count(*) filter (where l.nff_verdict in ('nff_wasteful','misdiagnosis')) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3296_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3296_engineer_scorecard() to authenticated;

-- 3) Equipment type × workshop finding matrix
create or replace function public.founder_r3296_equipment_finding_matrix()
returns table(
  equipment_type text,
  workshop_finding text,
  cases bigint,
  nff_cases bigint,
  avg_wasted_part_cost_rupees numeric,
  avg_freight_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.workshop_finding, count(*)::bigint,
    count(*) filter (where l.nff_verdict in ('nff_wasteful','misdiagnosis'))::bigint,
    round(avg(l.wasted_part_cost_rupees), 0),
    round(avg(l.freight_cost_rupees), 0)
  from public.nff_return_r3296 l
  group by l.equipment_type, l.workshop_finding
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3296_equipment_finding_matrix() from public, anon;
grant execute on function public.founder_r3296_equipment_finding_matrix() to authenticated;

-- 4) Daily case trend
create or replace function public.founder_r3296_daily_case_trend()
returns table(
  case_date date,
  cases bigint,
  nff_cases bigint,
  misdiagnosis_cases bigint,
  repeat_dispatches bigint,
  wasted_cost_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.case_date,
    count(*)::bigint,
    count(*) filter (where l.nff_verdict = 'nff_wasteful')::bigint,
    count(*) filter (where l.nff_verdict = 'misdiagnosis')::bigint,
    count(*) filter (where l.repeat_dispatch_needed)::bigint,
    coalesce(sum(l.wasted_part_cost_rupees),0)::numeric
  from public.nff_return_r3296 l
  group by l.case_date
  order by l.case_date desc;
end;
$$;

revoke execute on function public.founder_r3296_daily_case_trend() from public, anon;
grant execute on function public.founder_r3296_daily_case_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3296_capa_status_board()
returns table(capa_status text, findings bigint, avg_recoverable_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recoverable_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.nff_return_capa_actions_r3296 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3296_capa_status_board() from public, anon;
grant execute on function public.founder_r3296_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3296_root_cause_pareto()
returns table(root_cause text, occurrences bigint, wasted_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nff_return_r3296)
  select l.root_cause, count(*)::bigint,
    coalesce(sum(l.wasted_part_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nff_return_r3296 l
  group by l.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3296_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3296_root_cause_pareto() to authenticated;

-- 7) Region waste-cost digest (cost / risk digest)
create or replace function public.founder_r3296_region_waste_digest()
returns table(
  region text,
  cases bigint,
  nff_cases bigint,
  wasted_part_cost_rupees numeric,
  freight_cost_rupees numeric,
  total_waste_rupees numeric
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
    count(*) filter (where l.nff_verdict in ('nff_wasteful','misdiagnosis'))::bigint,
    coalesce(sum(l.wasted_part_cost_rupees),0)::numeric,
    coalesce(sum(l.freight_cost_rupees),0)::numeric,
    coalesce(sum(coalesce(l.wasted_part_cost_rupees,0) + coalesce(l.freight_cost_rupees,0)),0)::numeric
  from public.nff_return_r3296 l
  group by l.region
  order by 6 desc;
end;
$$;

revoke execute on function public.founder_r3296_region_waste_digest() from public, anon;
grant execute on function public.founder_r3296_region_waste_digest() to authenticated;

-- 8) High-risk case queue (wasteful / misdiagnosis / needless part swaps)
create or replace function public.founder_r3296_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  job_code text,
  equipment_type text,
  workshop_finding text,
  part_replaced boolean,
  part_actually_faulty boolean,
  nff_verdict text,
  wasted_part_cost_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.job_code, l.equipment_type,
    l.workshop_finding, l.part_replaced, l.part_actually_faulty,
    l.nff_verdict, l.wasted_part_cost_rupees, l.notes
  from public.nff_return_r3296 l
  where l.nff_verdict in ('nff_wasteful','misdiagnosis')
     or l.workshop_finding in ('no_fault_found','different_fault','intermittent_unconfirmed')
     or (l.part_replaced and not l.part_actually_faulty)
     or l.repeat_dispatch_needed
  order by l.wasted_part_cost_rupees desc nulls last, l.case_date desc;
end;
$$;

revoke execute on function public.founder_r3296_high_risk_queue() from public, anon;
grant execute on function public.founder_r3296_high_risk_queue() to authenticated;
