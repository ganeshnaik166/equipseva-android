-- Round 3256: Engineer Standby / Swap-Unit Deployment & Recovery Tracker
-- Field-swap discipline — engineer × failed equipment type × swap condition out/back × days on site × paperwork × calibration-on-loan × recovery verdict × CAPA

-- =============================================================================
-- TABLE 1: standby_swap_r3256 — individual swap-unit deployment events
-- =============================================================================
create table if not exists public.standby_swap_r3256 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  failed_equipment_type text not null check (failed_equipment_type in (
    'patient_monitor','infusion_pump','syringe_pump','ecg_machine','spo2_module','suction_unit'
  )),
  swap_unit_code text not null,
  deploy_date date not null,
  expected_return_date date not null,
  actual_return_date date,
  days_on_site int not null,
  swap_condition_out text not null check (swap_condition_out in (
    'certified_ready','cosmetic_wear','expired_calibration'
  )),
  swap_condition_back text check (swap_condition_back in (
    'good','damaged','missing_accessories','not_recovered'
  )),
  paperwork_complete boolean not null,
  customer_signature_ok boolean not null,
  calibration_valid_during_loan boolean not null,
  swap_verdict text not null check (swap_verdict in (
    'recovered_clean','recovered_with_issues','overdue_on_site','lost_escalated','in_progress'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.standby_swap_r3256 enable row level security;

create index if not exists idx_standby_swap_r3256_org on public.standby_swap_r3256(organization_id);
create index if not exists idx_standby_swap_r3256_deploy on public.standby_swap_r3256(deploy_date);
create index if not exists idx_standby_swap_r3256_verdict on public.standby_swap_r3256(swap_verdict);

-- =============================================================================
-- TABLE 2: standby_swap_capa_actions_r3256 — recovery / escalation CAPA actions
-- =============================================================================
create table if not exists public.standby_swap_capa_actions_r3256 (
  id uuid primary key default gen_random_uuid(),
  swap_log_id uuid not null references public.standby_swap_r3256(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'overdue_recovery','damaged_swap_return','missing_accessories','calibration_lapse_on_loan',
    'paperwork_gap','signature_missing','swap_lost_untraceable'
  )),
  root_cause text not null check (root_cause in (
    'engineer_followup_missed','hospital_holding_unit','courier_delay','accessory_not_returned',
    'calibration_expired_mid_loan','documentation_backlog','ward_relocation_untracked','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_recovery_visit','escalate_to_hospital_admin','invoice_for_damage','replace_missing_accessories',
    'recall_and_recalibrate','complete_paperwork_retro','file_police_fir','write_off_and_replace','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_category text not null check (exposure_category in (
    'asset_loss','damage_cost','revenue_leakage','customer_dispute','calibration_compliance','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.standby_swap_capa_actions_r3256 enable row level security;

create index if not exists idx_standby_swap_capa_r3256_log on public.standby_swap_capa_actions_r3256(swap_log_id);
create index if not exists idx_standby_swap_capa_r3256_status on public.standby_swap_capa_actions_r3256(capa_status);

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

  -- 14 swap deployment rows
  insert into public.standby_swap_r3256 (
    organization_id, engineer_name, hospital_name, failed_equipment_type, swap_unit_code,
    deploy_date, expected_return_date, actual_return_date, days_on_site,
    swap_condition_out, swap_condition_back,
    paperwork_complete, customer_signature_ok, calibration_valid_during_loan,
    swap_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.fet, q.code,
    q.dd::date, q.erd::date, q.ard::date, q.dos,
    q.sco, q.scb,
    q.pw, q.cs, q.cal,
    q.sv, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai Greams Road','patient_monitor','SWAP-PM-001',
     '2026-06-20','2026-06-27','2026-06-26',6,
     'certified_ready','good',true,true,true,
     'recovered_clean','Repaired monitor reinstalled — swap recovered a day early with full challan'),
    ('Suresh Menon','CMC Vellore','infusion_pump','SWAP-IP-002',
     '2026-06-22','2026-06-29','2026-07-01',9,
     'certified_ready','missing_accessories',true,true,true,
     'recovered_with_issues','Drop sensor and mains cable not returned — chasing ward sister'),
    ('Anil Sharma','Fortis Gurgaon Sector 44','ecg_machine','SWAP-ECG-003',
     '2026-06-18','2026-06-25',null,30,
     'certified_ready','not_recovered',false,true,false,
     'overdue_on_site','Repaired ECG delivered but swap still on ward — recovery visit pending'),
    ('Priya Nair','Manipal Bengaluru Old Airport Road','syringe_pump','SWAP-SP-004',
     '2026-07-01','2026-07-08','2026-07-07',6,
     'cosmetic_wear','good',true,true,true,
     'recovered_clean','Cosmetic scuff noted at deploy — returned in same condition'),
    ('Vikram Singh','AIIMS Delhi Ansari Nagar','spo2_module','SWAP-SPO-005',
     '2026-06-25','2026-07-02','2026-07-04',9,
     'certified_ready','damaged',true,false,true,
     'recovered_with_issues','Casing cracked on return and recovery challan unsigned'),
    ('Ravi Kumar','KIMS Hyderabad Secunderabad','suction_unit','SWAP-SU-006',
     '2026-06-15','2026-06-22',null,33,
     'expired_calibration','not_recovered',false,false,false,
     'lost_escalated','Ward relocated mid-loan; swap untraceable — escalated to hospital admin'),
    ('Deepa Iyer','Apollo Chennai Greams Road','infusion_pump','SWAP-IP-007',
     '2026-07-10','2026-07-20',null,8,
     'certified_ready',null,true,true,true,
     'in_progress','Failed pump in workshop — PCB awaited, return visit booked'),
    ('Anil Sharma','Fortis Gurgaon Sector 44','patient_monitor','SWAP-PM-008',
     '2026-07-05','2026-07-12','2026-07-11',6,
     'certified_ready','good',true,true,true,
     'recovered_clean','Clean swap cycle — recovered on repaired-unit reinstall'),
    ('Suresh Menon','CMC Vellore','ecg_machine','SWAP-ECG-009',
     '2026-06-28','2026-07-05','2026-07-09',11,
     'cosmetic_wear','good',false,true,true,
     'recovered_with_issues','Loan register entry missed at deploy — paperwork completed retroactively'),
    ('Priya Nair','Manipal Bengaluru Old Airport Road','patient_monitor','SWAP-PM-010',
     '2026-07-12','2026-07-19',null,6,
     'certified_ready',null,true,true,true,
     'in_progress','Repair ETA 19 Jul — swap running clean on ICU bed 4'),
    ('Vikram Singh','AIIMS Delhi Ansari Nagar','infusion_pump','SWAP-IP-011',
     '2026-06-10','2026-06-17','2026-06-30',20,
     'expired_calibration','good',true,true,false,
     'recovered_with_issues','Swap calibration expired mid-loan — recalled and recalibrated'),
    ('Deepa Iyer','Sankara Nethralaya Chennai','suction_unit','SWAP-SU-012',
     '2026-07-03','2026-07-10','2026-07-10',7,
     'certified_ready','good',true,true,true,
     'recovered_clean','On-time recovery with signed gate pass'),
    ('Mohan Das','Narayana Health City Bengaluru','syringe_pump','SWAP-SP-013',
     '2026-06-24','2026-07-01',null,24,
     'certified_ready','not_recovered',true,true,true,
     'overdue_on_site','Hospital holding swap as backup — recovery blocked by ICU census'),
    ('Mohan Das','Narayana Health City Bengaluru','spo2_module','SWAP-SPO-014',
     '2026-07-08','2026-07-15','2026-07-14',6,
     'certified_ready','good',true,true,true,
     'recovered_clean','Module swap recovered clean — accessories verified against checklist')
  ) as q(eng, hosp, fet, code, dd, erd, ard, dos, sco, scb, pw, cs, cal, sv, nt);

  -- CAPA seed — attach to specific swap events via swap unit code
  insert into public.standby_swap_capa_actions_r3256 (
    swap_log_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_category, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ec, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SWAP-ECG-003','overdue_recovery','engineer_followup_missed','schedule_recovery_visit','in_progress','asset_loss','2026-07-22',null,0.00,'Recovery visit booked with ward incharge for 21 Jul'),
    ('SWAP-SU-006','swap_lost_untraceable','ward_relocation_untracked','escalate_to_hospital_admin','escalated','asset_loss','2026-07-25',null,85000.00,'Suction unit missing after ward shift — admin escalation, FIR under review'),
    ('SWAP-IP-002','missing_accessories','accessory_not_returned','replace_missing_accessories','open','damage_cost','2026-07-24',null,6500.00,'Drop sensor + mains cable to be billed if not returned by Friday'),
    ('SWAP-SPO-005','damaged_swap_return','pending_investigation','invoice_for_damage','verification_pending','customer_dispute','2026-07-20',null,12000.00,'Cracked casing photos shared with biomedical HOD — damage invoice drafted'),
    ('SWAP-IP-011','calibration_lapse_on_loan','calibration_expired_mid_loan','recall_and_recalibrate','closed','calibration_compliance','2026-07-05','2026-07-02',4500.00,'Swap recalled, recalibrated and certificate reissued'),
    ('SWAP-ECG-009','paperwork_gap','documentation_backlog','complete_paperwork_retro','closed','internal_only','2026-07-12','2026-07-10',0.00,'Loan register backfilled and countersigned by branch lead'),
    ('SWAP-SP-013','overdue_recovery','hospital_holding_unit','escalate_to_hospital_admin','overdue','revenue_leakage','2026-07-10',null,30000.00,'Swap held as free backup past target — commercial escalation raised')
  ) as q(code, fc, rc, ca, cst, ec, tcd, acd, cost, nt)
  join public.standby_swap_r3256 e
    on e.organization_id = v_org_id and e.swap_unit_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Swap verdict distribution
create or replace function public.founder_r3256_swap_verdict_rollup()
returns table(swap_verdict text, swaps bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.standby_swap_r3256)
  select l.swap_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.standby_swap_r3256 l
  group by l.swap_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_swap_verdict_rollup() from public, anon;
grant execute on function public.founder_r3256_swap_verdict_rollup() to authenticated;

-- 2) Engineer swap-discipline scorecard
create or replace function public.founder_r3256_engineer_scorecard()
returns table(
  engineer_name text,
  total_swaps bigint,
  recovered_clean bigint,
  recovered_with_issues bigint,
  overdue_or_lost bigint,
  paperwork_gaps bigint,
  avg_days_on_site numeric,
  clean_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.swap_verdict = 'recovered_clean')::bigint,
    count(*) filter (where l.swap_verdict = 'recovered_with_issues')::bigint,
    count(*) filter (where l.swap_verdict in ('overdue_on_site','lost_escalated'))::bigint,
    count(*) filter (where l.paperwork_complete = false or l.customer_signature_ok = false)::bigint,
    round(avg(l.days_on_site)::numeric, 1),
    round(100.0 * count(*) filter (where l.swap_verdict = 'recovered_clean')::numeric / nullif(count(*),0), 1)
  from public.standby_swap_r3256 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3256_engineer_scorecard() to authenticated;

-- 3) Equipment type × condition-back matrix
create or replace function public.founder_r3256_equipment_condition_matrix()
returns table(failed_equipment_type text, swap_condition_back text, swaps bigint, recovered_clean bigint, avg_days_on_site numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.failed_equipment_type, coalesce(l.swap_condition_back, 'still_on_site'), count(*)::bigint,
    count(*) filter (where l.swap_verdict = 'recovered_clean')::bigint,
    round(avg(l.days_on_site)::numeric, 1)
  from public.standby_swap_r3256 l
  group by l.failed_equipment_type, coalesce(l.swap_condition_back, 'still_on_site')
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_equipment_condition_matrix() from public, anon;
grant execute on function public.founder_r3256_equipment_condition_matrix() to authenticated;

-- 4) Daily deployment trend
create or replace function public.founder_r3256_daily_deploy_trend()
returns table(deploy_date date, swaps bigint, recovered bigint, overdue_or_lost bigint, in_progress bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.deploy_date,
    count(*)::bigint,
    count(*) filter (where l.swap_verdict in ('recovered_clean','recovered_with_issues'))::bigint,
    count(*) filter (where l.swap_verdict in ('overdue_on_site','lost_escalated'))::bigint,
    count(*) filter (where l.swap_verdict = 'in_progress')::bigint
  from public.standby_swap_r3256 l
  group by l.deploy_date
  order by l.deploy_date desc;
end;
$$;

revoke execute on function public.founder_r3256_daily_deploy_trend() from public, anon;
grant execute on function public.founder_r3256_daily_deploy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3256_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.standby_swap_capa_actions_r3256 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_capa_status_board() from public, anon;
grant execute on function public.founder_r3256_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3256_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.standby_swap_capa_actions_r3256)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.standby_swap_capa_actions_r3256 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3256_root_cause_pareto() to authenticated;

-- 7) Exposure (cost/risk) digest
create or replace function public.founder_r3256_exposure_digest()
returns table(exposure_category text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.exposure_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','overdue','escalated'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.standby_swap_capa_actions_r3256 c
  group by c.exposure_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3256_exposure_digest() from public, anon;
grant execute on function public.founder_r3256_exposure_digest() to authenticated;

-- 8) High-risk swap queue (top individual concerns)
create or replace function public.founder_r3256_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  swap_unit_code text,
  failed_equipment_type text,
  deploy_date date,
  expected_return_date date,
  days_on_site int,
  swap_verdict text,
  swap_condition_back text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.swap_unit_code, l.failed_equipment_type,
    l.deploy_date, l.expected_return_date, l.days_on_site,
    l.swap_verdict, l.swap_condition_back, l.notes
  from public.standby_swap_r3256 l
  where l.swap_verdict in ('recovered_with_issues','overdue_on_site','lost_escalated')
     or l.swap_condition_back in ('damaged','missing_accessories','not_recovered')
     or l.paperwork_complete = false
     or l.customer_signature_ok = false
     or l.calibration_valid_during_loan = false
  order by l.days_on_site desc, l.deploy_date asc;
end;
$$;

revoke execute on function public.founder_r3256_high_risk_queue() from public, anon;
grant execute on function public.founder_r3256_high_risk_queue() to authenticated;
