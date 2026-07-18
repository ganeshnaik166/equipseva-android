-- Round 3267: Customer Hospital Endoscopy / Arthroscopy / Laparoscopy Tower Camera & Light QC Audit
-- Surgical tower QA — tower type × camera resolution × white balance × light-source lumen × light-guide fiber loss × insufflator flow/pressure × monitor cal × scope leak × CAPA

-- =============================================================================
-- TABLE 1: endoscopy_tower_r3267 — per-tower surgical imaging QC checks
-- =============================================================================
create table if not exists public.endoscopy_tower_r3267 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  tower_code text not null,
  tower_type text not null check (tower_type in (
    'laparoscopy_hd','laparoscopy_4k','arthroscopy','ent_endoscopy','urology_cysto'
  )),
  ot_number text not null,
  light_source_type text not null check (light_source_type in (
    'xenon','led','hybrid_led'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  camera_resolution_test text not null check (camera_resolution_test in (
    'excellent','acceptable','degraded','fail'
  )),
  white_balance_ok boolean not null,
  light_source_lumen_pct numeric(5,2) not null,
  light_guide_fiber_loss_pct numeric(5,2) not null,
  insufflator_flow_accuracy_error_pct numeric(5,2),
  insufflator_pressure_relief_ok boolean not null,
  monitor_calibration_ok boolean not null,
  leak_test_scope text not null check (leak_test_scope in (
    'pass','minor_leak','fail','not_applicable'
  )),
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.endoscopy_tower_r3267 enable row level security;

create index if not exists idx_endoscopy_tower_r3267_org on public.endoscopy_tower_r3267(organization_id);
create index if not exists idx_endoscopy_tower_r3267_date on public.endoscopy_tower_r3267(check_date);
create index if not exists idx_endoscopy_tower_r3267_verdict on public.endoscopy_tower_r3267(qc_verdict);

-- =============================================================================
-- TABLE 2: endoscopy_tower_capa_actions_r3267 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.endoscopy_tower_capa_actions_r3267 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.endoscopy_tower_r3267(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'camera_resolution_degraded','white_balance_failure','light_source_output_low','light_guide_fiber_damage',
    'insufflator_flow_deviation','insufflator_pressure_relief_failure','monitor_calibration_drift',
    'scope_leak_detected','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'ccu_sensor_degraded','camera_head_coupler_worn','lamp_module_end_of_life','led_driver_fault',
    'light_guide_fibers_broken','insufflator_valve_wear','pressure_relief_valve_stuck','monitor_panel_aging',
    'scope_seal_perished','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_camera_head','recouple_ccu','replace_lamp_module','replace_led_driver','replace_light_guide_cable',
    'rebuild_insufflator_valve','replace_pressure_relief_valve','recalibrate_monitor','replace_scope_seals',
    'retrain_ot_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.endoscopy_tower_capa_actions_r3267 enable row level security;

create index if not exists idx_endoscopy_capa_r3267_log on public.endoscopy_tower_capa_actions_r3267(qc_log_id);
create index if not exists idx_endoscopy_capa_r3267_status on public.endoscopy_tower_capa_actions_r3267(capa_status);

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

  -- 14 tower QC rows
  insert into public.endoscopy_tower_r3267 (
    organization_id, hospital_name, tower_code, tower_type, ot_number, light_source_type,
    check_date, checked_at, camera_resolution_test, white_balance_ok,
    light_source_lumen_pct, light_guide_fiber_loss_pct, insufflator_flow_accuracy_error_pct,
    insufflator_pressure_relief_ok, monitor_calibration_ok, leak_test_scope, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.tcode, q.ttype, q.otn, q.lst,
    q.cd::date, q.ts::timestamptz, q.crt, q.wb,
    q.lumen, q.fiber, q.insuff_err,
    q.prv, q.moncal, q.leak, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','TWR-APL-01','laparoscopy_4k','OT-3','led','2026-07-08','2026-07-08 08:10:00+05:30','excellent',true,
     96.50,2.10,1.20,true,true,'pass','pass','Routine QC — 4K imaging chain nominal'),
    ('Apollo Chennai Greams Road','TWR-APL-02','laparoscopy_hd','OT-4','xenon','2026-07-08','2026-07-08 09:20:00+05:30','acceptable',true,
     78.00,6.50,3.10,true,true,'pass','conditional_pass','Xenon lamp at 78% output — high lamp hours, replacement planned'),
    ('Fortis Gurgaon','TWR-FRT-01','arthroscopy','OT-2','led','2026-07-07','2026-07-07 07:40:00+05:30','excellent',true,
     94.20,1.40,null,true,true,'not_applicable','pass','Arthroscopy tower clean — fluid pump, no CO2 insufflator'),
    ('Fortis Gurgaon','TWR-FRT-02','laparoscopy_hd','OT-5','xenon','2026-07-07','2026-07-07 08:50:00+05:30','degraded',false,
     62.00,14.00,8.40,false,true,'minor_leak','fail','Camera degraded, white-balance fail, relief valve stuck, fiber loss 14%'),
    ('Manipal Bengaluru Old Airport Road','TWR-MNP-01','urology_cysto','OT-1','led','2026-07-06','2026-07-06 07:15:00+05:30','acceptable',true,
     85.50,4.20,null,true,true,'pass','pass','Cystoscopy tower QC pass'),
    ('Manipal Bengaluru Old Airport Road','TWR-MNP-02','laparoscopy_4k','OT-6','hybrid_led','2026-07-06','2026-07-06 08:30:00+05:30','acceptable',true,
     88.00,3.00,5.60,true,false,'pass','conditional_pass','Monitor calibration drift on 4K panel — recal scheduled'),
    ('AIIMS New Delhi Ansari Nagar','TWR-AIM-01','ent_endoscopy','OT-7','led','2026-07-05','2026-07-05 06:50:00+05:30','excellent',true,
     92.00,2.50,null,true,true,'pass','pass','ENT scope tower nominal'),
    ('AIIMS New Delhi Ansari Nagar','TWR-AIM-02','laparoscopy_hd','OT-8','xenon','2026-07-05','2026-07-05 08:05:00+05:30','fail',false,
     55.00,22.00,12.00,false,false,'fail','removed_from_service','Multiple failures — camera fail, scope leak, unit pulled from service'),
    ('CMC Vellore','TWR-CMC-01','laparoscopy_4k','OT-2','led','2026-07-04','2026-07-04 07:25:00+05:30','excellent',true,
     97.00,1.00,0.90,true,true,'pass','pass','New 4K stack — excellent across all checks'),
    ('CMC Vellore','TWR-CMC-02','arthroscopy','OT-3','xenon','2026-07-04','2026-07-04 08:40:00+05:30','acceptable',true,
     71.50,9.20,null,true,true,'minor_leak','conditional_pass','Light-guide fiber loss 9.2%, minor scope leak — watch'),
    ('KIMS Hyderabad Secunderabad','TWR-KIM-01','laparoscopy_hd','OT-4','led','2026-07-03','2026-07-03 07:05:00+05:30','degraded',true,
     68.00,11.50,9.80,true,true,'pass','fail','Insufflator flow error 9.8%, light output low 68%, camera degraded'),
    ('KIMS Hyderabad Secunderabad','TWR-KIM-02','urology_cysto','OT-1','hybrid_led','2026-07-03','2026-07-03 08:20:00+05:30','excellent',true,
     91.00,2.00,null,true,true,'pass','pass','Cysto tower nominal'),
    ('Narayana Health Bengaluru','TWR-NAR-01','laparoscopy_4k','OT-9','led','2026-07-02','2026-07-02 07:35:00+05:30','acceptable',true,
     82.00,5.00,6.20,true,true,'pass','conditional_pass','Insufflator flow error 6.2% just above 5% tolerance — recheck booked'),
    ('Medanta Gurgaon','TWR-MED-01','ent_endoscopy','OT-2','xenon','2026-07-02','2026-07-02 08:55:00+05:30','degraded',false,
     60.00,16.00,null,true,false,'fail','removed_from_service','ENT scope leak fail + camera degraded + monitor drift — removed')
  ) as q(hosp, tcode, ttype, otn, lst, cd, ts, crt, wb, lumen, fiber, insuff_err, prv, moncal, leak, qv, nt);

  -- CAPA seed — attach to specific towers via tower_code
  insert into public.endoscopy_tower_capa_actions_r3267 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TWR-FRT-02','insufflator_pressure_relief_failure','pressure_relief_valve_stuck','replace_pressure_relief_valve','in_progress','patient_safety_alert','2026-07-12',null,22000.00,'Relief valve stuck closed — safety alert, replacement in progress'),
    ('TWR-AIM-02','scope_leak_detected','scope_seal_perished','replace_scope_seals','escalated','cdsco_notifiable','2026-07-10',null,48000.00,'Scope leak fail plus camera fail — unit removed, OEM escalation'),
    ('TWR-KIM-01','insufflator_flow_deviation','insufflator_valve_wear','rebuild_insufflator_valve','open','nabh_finding','2026-07-14',null,35000.00,'Flow error 9.8% — insufflator valve rebuild scheduled'),
    ('TWR-APL-02','light_source_output_low','lamp_module_end_of_life','replace_lamp_module','verification_pending','internal_only','2026-07-11',null,28000.00,'Xenon lamp end of life — replaced, verifying output'),
    ('TWR-MED-01','scope_leak_detected','scope_seal_perished','replace_scope_seals','closed','iso_13485_deviation','2026-07-08','2026-07-06',46000.00,'ENT scope seals replaced, leak test passed'),
    ('TWR-CMC-02','light_guide_fiber_damage','light_guide_fibers_broken','replace_light_guide_cable','open','internal_only','2026-07-09',null,9500.00,'Fiber loss 9.2% — light-guide cable on order'),
    ('TWR-FRT-02','camera_resolution_degraded','camera_head_coupler_worn','replace_camera_head','overdue','nabh_finding','2026-06-30',null,62000.00,'Camera head degraded — replacement past target, AMC vendor delayed')
  ) as q(tcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.endoscopy_tower_r3267 e
    on e.organization_id = v_org_id and e.tower_code = q.tcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3267_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.endoscopy_tower_r3267)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.endoscopy_tower_r3267 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3267_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3267_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  camera_degraded bigint,
  light_low bigint,
  scope_leak bigint,
  pass_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.camera_resolution_test in ('degraded','fail'))::bigint,
    count(*) filter (where l.light_source_lumen_pct < 70)::bigint,
    count(*) filter (where l.leak_test_scope in ('minor_leak','fail'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.endoscopy_tower_r3267 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3267_hospital_scorecard() to authenticated;

-- 3) Tower type × light-source type matrix
create or replace function public.founder_r3267_tower_light_matrix()
returns table(tower_type text, light_source_type text, audits bigint, passed bigint, avg_lumen_pct numeric, avg_fiber_loss_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tower_type, l.light_source_type, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.light_source_lumen_pct), 1),
    round(avg(l.light_guide_fiber_loss_pct), 1)
  from public.endoscopy_tower_r3267 l
  group by l.tower_type, l.light_source_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_tower_light_matrix() from public, anon;
grant execute on function public.founder_r3267_tower_light_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3267_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, camera_degraded bigint, scope_leak bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.camera_resolution_test in ('degraded','fail'))::bigint,
    count(*) filter (where l.leak_test_scope in ('minor_leak','fail'))::bigint
  from public.endoscopy_tower_r3267 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3267_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3267_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3267_capa_status_board()
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
  from public.endoscopy_tower_capa_actions_r3267 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_capa_status_board() from public, anon;
grant execute on function public.founder_r3267_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3267_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.endoscopy_tower_capa_actions_r3267)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.endoscopy_tower_capa_actions_r3267 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3267_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3267_regulatory_impact_digest()
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
  from public.endoscopy_tower_capa_actions_r3267 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3267_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3267_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3267_high_risk_queue()
returns table(
  hospital_name text,
  tower_code text,
  tower_type text,
  check_date date,
  qc_verdict text,
  camera_resolution_test text,
  leak_test_scope text,
  light_source_lumen_pct numeric,
  light_guide_fiber_loss_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.tower_code, l.tower_type, l.check_date,
    l.qc_verdict, l.camera_resolution_test, l.leak_test_scope,
    l.light_source_lumen_pct, l.light_guide_fiber_loss_pct, l.notes
  from public.endoscopy_tower_r3267 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.camera_resolution_test in ('degraded','fail')
     or l.leak_test_scope in ('minor_leak','fail')
     or l.light_source_lumen_pct < 70
     or l.light_guide_fiber_loss_pct >= 10
     or l.white_balance_ok = false
     or l.insufflator_pressure_relief_ok = false
     or l.monitor_calibration_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3267_high_risk_queue() from public, anon;
grant execute on function public.founder_r3267_high_risk_queue() to authenticated;
