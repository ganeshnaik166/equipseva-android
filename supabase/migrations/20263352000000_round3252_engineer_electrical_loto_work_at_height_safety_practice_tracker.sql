-- Round 3252: Engineer Electrical LOTO & Work-at-Height Safety-Practice Tracker
-- Field-safety QA — hazard type × LOTO applied × de-energized verification × height work × access-equipment condition × harness × permit-to-work × second person × CAPA

-- =============================================================================
-- TABLE 1: engineer_loto_height_safety_r3252 — per observed/audited service job
-- =============================================================================
create table if not exists public.engineer_loto_height_safety_r3252 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  job_code text not null,
  job_date date not null,
  hazard_type text not null check (hazard_type in (
    'mains_electrical','capacitor_stored_energy','ceiling_mounted_equipment',
    'ups_battery_bank','medical_gas_pressure'
  )),
  loto_applied text not null check (loto_applied in (
    'full_loto','tag_only','not_applied','not_required'
  )),
  loto_verification_test boolean not null default false,
  height_work_involved boolean not null default false,
  ladder_or_scaffold_condition text not null check (ladder_or_scaffold_condition in (
    'certified','uncertified','defective','not_applicable'
  )),
  harness_used text not null check (harness_used in (
    'yes','no','not_required'
  )),
  permit_to_work_obtained boolean not null default false,
  second_person_present boolean not null default false,
  violation_count int not null default 0,
  practice_verdict text not null check (practice_verdict in (
    'compliant','minor_gap','major_violation','stop_work_issued'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_loto_height_safety_r3252 enable row level security;

create index if not exists idx_loto_height_r3252_org on public.engineer_loto_height_safety_r3252(organization_id);
create index if not exists idx_loto_height_r3252_date on public.engineer_loto_height_safety_r3252(job_date);
create index if not exists idx_loto_height_r3252_verdict on public.engineer_loto_height_safety_r3252(practice_verdict);

-- =============================================================================
-- TABLE 2: engineer_loto_height_safety_capa_actions_r3252 — CAPA & retraining actions
-- =============================================================================
create table if not exists public.engineer_loto_height_safety_capa_actions_r3252 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.engineer_loto_height_safety_r3252(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'loto_not_applied','tag_without_lock','no_deenergized_verification',
    'uncertified_access_equipment','harness_not_used','permit_bypass',
    'lone_working','stored_energy_discharge_gap'
  )),
  root_cause text not null check (root_cause in (
    'time_pressure','loto_kit_unavailable','training_gap','permit_process_unclear',
    'access_equipment_shortage','complacency_habit','supervision_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer','issue_loto_kit','suspend_from_field_work','revise_permit_workflow',
    'procure_certified_access_equipment','buddy_system_enforcement','toolbox_talk_refresher',
    'disciplinary_escalation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'factories_act_finding','electricity_rules_breach','internal_only',
    'client_hospital_escalation','insurance_notifiable','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_loto_height_safety_capa_actions_r3252 enable row level security;

create index if not exists idx_loto_capa_r3252_audit on public.engineer_loto_height_safety_capa_actions_r3252(audit_id);
create index if not exists idx_loto_capa_r3252_status on public.engineer_loto_height_safety_capa_actions_r3252(capa_status);

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

  -- 14 observed/audited service jobs
  insert into public.engineer_loto_height_safety_r3252 (
    organization_id, engineer_name, hospital_name, job_code, job_date,
    hazard_type, loto_applied, loto_verification_test, height_work_involved,
    ladder_or_scaffold_condition, harness_used, permit_to_work_obtained,
    second_person_present, violation_count, practice_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.jc, q.jd::date,
    q.hz, q.la, q.lvt, q.hw,
    q.lsc, q.hu, q.ptw,
    q.spp, q.vc, q.pv, q.nt
  from (values
    ('Ravi Kumar','Apollo Hospitals Chennai Greams Road','JOB-APL-9001','2026-07-03',
     'mains_electrical','full_loto',true,false,'not_applicable','not_required',true,true,0,'compliant','CT gantry mains service — textbook isolation and two-pole verification'),
    ('Suresh Nair','Apollo Hospitals Chennai Greams Road','JOB-APL-9002','2026-07-03',
     'capacitor_stored_energy','tag_only',false,false,'not_applicable','not_required',true,true,2,'major_violation','Defib capacitor bank tagged but not locked, no discharge verification'),
    ('Amit Sharma','Fortis Memorial Gurgaon','JOB-FRT-9101','2026-07-02',
     'ceiling_mounted_equipment','full_loto',true,true,'certified','yes',true,true,0,'compliant','OT pendant service from certified scaffold with full harness'),
    ('Priya Venkatesan','Fortis Memorial Gurgaon','JOB-FRT-9102','2026-07-02',
     'ceiling_mounted_equipment','full_loto',true,true,'uncertified','no',true,true,2,'major_violation','Uncertified ladder used with no harness at 3.5 m — work paused'),
    ('Mohammed Irfan','Manipal Hospital Bengaluru Old Airport Road','JOB-MNP-9201','2026-07-01',
     'ups_battery_bank','full_loto',true,false,'not_applicable','not_required',true,true,0,'compliant','UPS battery string isolation verified with two-point test'),
    ('Deepak Joshi','Manipal Hospital Bengaluru Old Airport Road','JOB-MNP-9202','2026-07-01',
     'mains_electrical','not_applied',false,false,'not_applicable','not_required',false,false,4,'stop_work_issued','Live 415V panel opened without isolation or permit — stop-work issued'),
    ('Karthik Subramani','AIIMS New Delhi','JOB-AIM-9301','2026-06-30',
     'medical_gas_pressure','full_loto',true,false,'not_applicable','not_required',true,true,0,'compliant','Gas manifold line depressurised and valve locked before service'),
    ('Anil Patil','AIIMS New Delhi','JOB-AIM-9302','2026-06-30',
     'ceiling_mounted_equipment','full_loto',true,true,'certified','no',true,true,1,'minor_gap','Harness available on site but not worn at top of scaffold'),
    ('Sunita Reddy','CMC Vellore','JOB-CMC-9401','2026-06-29',
     'mains_electrical','full_loto',false,false,'not_applicable','not_required',true,true,1,'minor_gap','Lock applied but de-energised state not test-verified before work'),
    ('Vikram Singh','CMC Vellore','JOB-CMC-9402','2026-06-29',
     'capacitor_stored_energy','full_loto',true,false,'not_applicable','not_required',true,false,1,'minor_gap','X-ray HT capacitor discharge done solo — second person absent'),
    ('Farhan Sheikh','KIMS Hyderabad Secunderabad','JOB-KIM-9501','2026-06-28',
     'ceiling_mounted_equipment','tag_only',false,true,'defective','no',false,false,5,'stop_work_issued','Defective scaffold, no harness, no permit for ceiling column work'),
    ('Rajesh Iyer','KIMS Hyderabad Secunderabad','JOB-KIM-9502','2026-06-28',
     'ups_battery_bank','full_loto',true,false,'not_applicable','not_required',true,true,0,'compliant','Battery bank isolation verified, insulated tools used throughout'),
    ('Neha Kulkarni','Kokilaben Dhirubhai Ambani Mumbai','JOB-KDA-9601','2026-06-27',
     'mains_electrical','full_loto',true,true,'certified','yes',true,true,0,'compliant','AHU-mounted UV unit service — full LOTO plus certified platform'),
    ('Arjun Menon','Kokilaben Dhirubhai Ambani Mumbai','JOB-KDA-9602','2026-06-27',
     'medical_gas_pressure','not_applied',false,false,'not_applicable','not_required',true,true,2,'major_violation','Vacuum pump serviced with line still pressurised — no isolation lock')
  ) as q(eng, hosp, jc, jd, hz, la, lvt, hw, lsc, hu, ptw, spp, vc, pv, nt);

  -- CAPA seed — attach to specific audited jobs via job code
  insert into public.engineer_loto_height_safety_capa_actions_r3252 (
    audit_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-APL-9002','stored_energy_discharge_gap','training_gap','retrain_engineer','in_progress','electricity_rules_breach','2026-07-10',null,8000.00,'Capacitor discharge SOP retraining scheduled with OEM trainer'),
    ('JOB-FRT-9102','uncertified_access_equipment','access_equipment_shortage','procure_certified_access_equipment','open','client_hospital_escalation','2026-07-15',null,145000.00,'Certified mobile scaffold on order for Gurgaon zone'),
    ('JOB-MNP-9202','loto_not_applied','complacency_habit','suspend_from_field_work','escalated','electricity_rules_breach','2026-07-05',null,0.00,'Engineer suspended pending inquiry — live 415V panel breach'),
    ('JOB-KIM-9501','permit_bypass','supervision_gap','disciplinary_escalation','in_progress','factories_act_finding','2026-07-12',null,25000.00,'Zone supervisor accountability review plus scaffold condemned'),
    ('JOB-KDA-9602','loto_not_applied','permit_process_unclear','revise_permit_workflow','verification_pending','client_hospital_escalation','2026-07-08',null,12000.00,'Gas-line isolation added to permit checklist — verify next job'),
    ('JOB-CMC-9401','no_deenergized_verification','loto_kit_unavailable','issue_loto_kit','closed','internal_only','2026-07-02','2026-06-30',6500.00,'Two-pole voltage tester issued to CMC resident engineer'),
    ('JOB-AIM-9302','harness_not_used','training_gap','toolbox_talk_refresher','closed','internal_only','2026-07-01','2026-06-30',0.00,'Work-at-height toolbox talk delivered to Delhi field team')
  ) as q(jc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.engineer_loto_height_safety_r3252 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Practice verdict distribution
create or replace function public.founder_r3252_practice_verdict_rollup()
returns table(practice_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_loto_height_safety_r3252)
  select l.practice_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_loto_height_safety_r3252 l
  group by l.practice_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_practice_verdict_rollup() from public, anon;
grant execute on function public.founder_r3252_practice_verdict_rollup() to authenticated;

-- 2) Engineer safety scorecard
create or replace function public.founder_r3252_engineer_scorecard()
returns table(
  engineer_name text,
  total_jobs bigint,
  compliant bigint,
  minor_gaps bigint,
  major_violations bigint,
  stop_work bigint,
  loto_gaps bigint,
  permit_missing bigint,
  total_violations bigint,
  compliance_pct numeric
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
    count(*) filter (where l.practice_verdict = 'compliant')::bigint,
    count(*) filter (where l.practice_verdict = 'minor_gap')::bigint,
    count(*) filter (where l.practice_verdict = 'major_violation')::bigint,
    count(*) filter (where l.practice_verdict = 'stop_work_issued')::bigint,
    count(*) filter (where l.loto_applied in ('tag_only','not_applied'))::bigint,
    count(*) filter (where l.permit_to_work_obtained = false)::bigint,
    coalesce(sum(l.violation_count),0)::bigint,
    round(100.0 * count(*) filter (where l.practice_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.engineer_loto_height_safety_r3252 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3252_engineer_scorecard() to authenticated;

-- 3) Hazard type × LOTO applied matrix
create or replace function public.founder_r3252_hazard_loto_matrix()
returns table(hazard_type text, loto_applied text, jobs bigint, verified_deenergized bigint, avg_violations numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hazard_type, l.loto_applied, count(*)::bigint,
    count(*) filter (where l.loto_verification_test)::bigint,
    round(avg(l.violation_count)::numeric, 2)
  from public.engineer_loto_height_safety_r3252 l
  group by l.hazard_type, l.loto_applied
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_hazard_loto_matrix() from public, anon;
grant execute on function public.founder_r3252_hazard_loto_matrix() to authenticated;

-- 4) Daily practice trend
create or replace function public.founder_r3252_daily_practice_trend()
returns table(job_date date, jobs bigint, compliant bigint, major_violations bigint, stop_work bigint, total_violations bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.job_date,
    count(*)::bigint,
    count(*) filter (where l.practice_verdict = 'compliant')::bigint,
    count(*) filter (where l.practice_verdict = 'major_violation')::bigint,
    count(*) filter (where l.practice_verdict = 'stop_work_issued')::bigint,
    coalesce(sum(l.violation_count),0)::bigint
  from public.engineer_loto_height_safety_r3252 l
  group by l.job_date
  order by l.job_date desc;
end;
$$;

revoke execute on function public.founder_r3252_daily_practice_trend() from public, anon;
grant execute on function public.founder_r3252_daily_practice_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3252_capa_status_board()
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
  from public.engineer_loto_height_safety_capa_actions_r3252 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_capa_status_board() from public, anon;
grant execute on function public.founder_r3252_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3252_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_loto_height_safety_capa_actions_r3252)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_loto_height_safety_capa_actions_r3252 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3252_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3252_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_loto_height_safety_capa_actions_r3252 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3252_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3252_regulatory_impact_digest() to authenticated;

-- 8) High-risk practice queue (top individual concerns)
create or replace function public.founder_r3252_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  job_code text,
  job_date date,
  hazard_type text,
  loto_applied text,
  ladder_or_scaffold_condition text,
  harness_used text,
  violation_count int,
  practice_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.job_code, l.job_date,
    l.hazard_type, l.loto_applied, l.ladder_or_scaffold_condition, l.harness_used,
    l.violation_count, l.practice_verdict, l.notes
  from public.engineer_loto_height_safety_r3252 l
  where l.practice_verdict in ('minor_gap','major_violation','stop_work_issued')
     or l.loto_applied in ('tag_only','not_applied')
     or l.ladder_or_scaffold_condition in ('uncertified','defective')
     or (l.height_work_involved and l.harness_used = 'no')
     or l.permit_to_work_obtained = false
     or l.violation_count > 0
  order by l.violation_count desc, l.job_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3252_high_risk_queue() from public, anon;
grant execute on function public.founder_r3252_high_risk_queue() to authenticated;
