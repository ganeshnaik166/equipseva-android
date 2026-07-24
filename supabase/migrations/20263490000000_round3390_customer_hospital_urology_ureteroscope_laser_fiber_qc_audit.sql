-- Round 3390: Customer Hospital Urology Ureteroscope & Laser-Fiber QC Audit
-- Urology scope QA — device type × department × deflection × image × channel patency × leak × laser-fiber transmission × fiber tip × sterilization × insertion tube × CAPA

-- =============================================================================
-- TABLE 1: ureteroscope_qc_r3390 — per-scope/fiber QC checks
-- =============================================================================
create table if not exists public.ureteroscope_qc_r3390 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  scope_code text not null,
  device_type text not null check (device_type in (
    'flexible_ureteroscope','semi_rigid_ureteroscope','digital_ureteroscope',
    'holmium_laser_fiber','reusable_laser_fiber'
  )),
  department text not null,
  check_date date not null,
  deflection_angle_ok boolean not null,
  image_quality text not null check (image_quality in (
    'excellent','acceptable','degraded','fail'
  )),
  channel_patency_ok boolean not null,
  leak_test text not null check (leak_test in (
    'pass','minor_leak','fail','not_applicable'
  )),
  laser_fiber_transmission_ok text not null check (laser_fiber_transmission_ok in (
    'ok','degraded','fail','not_applicable'
  )),
  fiber_tip_condition text not null check (fiber_tip_condition in (
    'good','burnt','frayed','replace_due','not_applicable'
  )),
  sterilization_cycle_ok boolean not null,
  insertion_tube_condition text not null check (insertion_tube_condition in (
    'good','worn','kinked','replace_due','not_applicable'
  )),
  reprocessing_traceable boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ureteroscope_qc_r3390 enable row level security;

create index if not exists idx_ureteroscope_qc_r3390_org on public.ureteroscope_qc_r3390(organization_id);
create index if not exists idx_ureteroscope_qc_r3390_date on public.ureteroscope_qc_r3390(check_date);
create index if not exists idx_ureteroscope_qc_r3390_verdict on public.ureteroscope_qc_r3390(qc_verdict);

-- =============================================================================
-- TABLE 2: ureteroscope_qc_capa_actions_r3390 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ureteroscope_qc_capa_actions_r3390 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ureteroscope_qc_r3390(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'deflection_loss','image_degraded','channel_blockage','leak_detected',
    'laser_transmission_loss','fiber_tip_damage','sterilization_failure',
    'insertion_tube_damage','reprocessing_gap','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mechanical_wear','fiber_end_of_life','channel_debris','seal_failure',
    'improper_handling','reprocessing_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','sterilizer_cycle_fault'
  )),
  corrective_action text not null check (corrective_action in (
    'repair_deflection_mechanism','replace_laser_fiber','clean_flush_channel','reseal_scope',
    'replace_insertion_tube','recalibrate','retrain_ot_staff','requalify_reprocessing',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.ureteroscope_qc_capa_actions_r3390 enable row level security;

create index if not exists idx_ureteroscope_capa_r3390_log on public.ureteroscope_qc_capa_actions_r3390(qc_log_id);
create index if not exists idx_ureteroscope_capa_r3390_status on public.ureteroscope_qc_capa_actions_r3390(capa_status);

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

  insert into public.ureteroscope_qc_r3390 (
    organization_id, hospital_name, scope_code, device_type, department, check_date,
    deflection_angle_ok, image_quality, channel_patency_ok, leak_test,
    laser_fiber_transmission_ok, fiber_tip_condition, sterilization_cycle_ok,
    insertion_tube_condition, reprocessing_traceable, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.scode, q.dtype, q.dept, q.cdate::date,
    q.defl, q.img, q.chan, q.leak,
    q.lft, q.ftip, q.steril,
    q.itube, q.reproc, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','URS-APL-01','flexible_ureteroscope','urology_ot','2026-07-03',
     true,'excellent',true,'pass','not_applicable','not_applicable',true,'good',true,true,'pass','Quarterly QC — flexible ureteroscope deflection and optics nominal'),
    ('Apollo Chennai','LF-APL-02','holmium_laser_fiber','urology_ot','2026-07-03',
     true,'acceptable',true,'not_applicable','ok','good',true,'not_applicable',true,true,'pass','Holmium laser fiber transmission within spec'),
    ('Fortis Gurgaon','URS-FRT-11','digital_ureteroscope','urology_ot','2026-07-02',
     true,'degraded',true,'pass','not_applicable','not_applicable',true,'worn',true,true,'conditional_pass','Digital scope image degraded and insertion tube worn — recheck booked'),
    ('Fortis Gurgaon','URS-FRT-12','flexible_ureteroscope','urology_ot','2026-07-02',
     false,'fail',false,'fail','not_applicable','not_applicable',true,'kinked',false,true,'fail','Deflection loss, channel blocked, leak and kinked tube — pulled'),
    ('Manipal Bengaluru','LF-MNP-21','reusable_laser_fiber','urology_ot','2026-07-01',
     true,'acceptable',true,'not_applicable','degraded','frayed',true,'not_applicable',true,false,'conditional_pass','Reusable laser fiber transmission degraded, tip frayed — calibration overdue'),
    ('Manipal Bengaluru','URS-MNP-22','semi_rigid_ureteroscope','urology_ot','2026-07-01',
     true,'excellent',true,'pass','not_applicable','not_applicable',true,'good',true,true,'pass','Semi-rigid ureteroscope QC pass'),
    ('AIIMS Delhi','URS-AIM-31','digital_ureteroscope','urology_ot','2026-06-30',
     true,'acceptable',true,'minor_leak','not_applicable','not_applicable',true,'good',true,true,'conditional_pass','Minor leak on pressure test — monitor and reseal'),
    ('AIIMS Delhi','LF-AIM-32','holmium_laser_fiber','urology_ot','2026-06-30',
     true,'acceptable',true,'not_applicable','fail','burnt',true,'not_applicable',true,true,'fail','Laser fiber transmission failed and tip burnt — replace'),
    ('CMC Vellore','URS-CMC-41','flexible_ureteroscope','urology_ot','2026-06-29',
     true,'excellent',true,'pass','not_applicable','not_applicable',true,'good',true,true,'pass','Flexible ureteroscope QC pass'),
    ('CMC Vellore','URS-CMC-42','flexible_ureteroscope','urology_ot','2026-06-29',
     true,'acceptable',true,'pass','not_applicable','not_applicable',false,'good',false,true,'conditional_pass','Sterilization cycle record and reprocessing traceability gap — requalify'),
    ('KIMS Hyderabad','URS-KIM-51','semi_rigid_ureteroscope','urology_ot','2026-06-28',
     true,'excellent',true,'pass','not_applicable','not_applicable',true,'good',true,true,'pass','Semi-rigid ureteroscope QC pass post-AMC'),
    ('KIMS Hyderabad','LF-KIM-52','reusable_laser_fiber','urology_ot','2026-06-28',
     true,'acceptable',true,'not_applicable','ok','replace_due',true,'not_applicable',true,true,'conditional_pass','Reusable fiber near end-of-life, tip replace-due — plan swap'),
    ('Yashoda Hyderabad','URS-YSH-61','digital_ureteroscope','urology_ot','2026-06-27',
     true,'excellent',true,'pass','not_applicable','not_applicable',true,'good',true,true,'pass','Digital ureteroscope QC nominal'),
    ('Kokilaben Mumbai','URS-KKB-71','flexible_ureteroscope','urology_ot','2026-06-27',
     false,'fail',false,'fail','not_applicable','not_applicable',false,'replace_due',false,false,'removed_from_service','Multiple failures across deflection, channel, leak and sterilization — removed')
  ) as q(hosp, scode, dtype, dept, cdate, defl, img, chan, leak, lft, ftip, steril, itube, reproc, calcur, qv, nt);

  insert into public.ureteroscope_qc_capa_actions_r3390 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('URS-FRT-12','deflection_loss','mechanical_wear','repair_deflection_mechanism','in_progress','iso_13485_deviation','2026-07-06',null,42000.00,'Deflection mechanism under repair; leak reseal after'),
    ('LF-MNP-21','laser_transmission_loss','fiber_end_of_life','replace_laser_fiber','open','internal_only','2026-07-05',null,28000.00,'Reusable fiber transmission degraded — replacement ordered'),
    ('LF-AIM-32','fiber_tip_damage','fiber_end_of_life','replace_laser_fiber','escalated','patient_safety_alert','2026-07-04',null,31000.00,'Burnt fiber tip with transmission fail — escalated'),
    ('URS-KKB-71','channel_blockage','reprocessing_error','requalify_reprocessing','closed','cdsco_notifiable','2026-07-02','2026-06-28',55000.00,'Scope removed; reprocessing requalified and loaner deployed'),
    ('URS-CMC-42','reprocessing_gap','reprocessing_error','requalify_reprocessing','verification_pending','nabh_finding','2026-07-05',null,6000.00,'Reprocessing traceability re-established — verify next cycle'),
    ('URS-FRT-11','image_degraded','mechanical_wear','replace_insertion_tube','overdue','internal_only','2026-06-30',null,38000.00,'Insertion tube replacement past target — vendor delay'),
    ('URS-AIM-31','leak_detected','seal_failure','reseal_scope','open','none','2026-07-07',null,9000.00,'Minor leak reseal scheduled; monitor pressure')
  ) as q(scode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ureteroscope_qc_r3390 e
    on e.organization_id = v_org_id and e.scope_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3390_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ureteroscope_qc_r3390)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ureteroscope_qc_r3390 l
  group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3390_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3390_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  image_fail bigint, leak_issue bigint, calibration_overdue bigint, pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.image_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.leak_test in ('minor_leak','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ureteroscope_qc_r3390 l
  group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3390_hospital_scorecard() to authenticated;

create or replace function public.founder_r3390_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, fiber_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.laser_fiber_transmission_ok in ('degraded','fail'))::bigint
  from public.ureteroscope_qc_r3390 l
  group by l.device_type, l.department order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_device_department_matrix() from public, anon;
grant execute on function public.founder_r3390_device_department_matrix() to authenticated;

create or replace function public.founder_r3390_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, image_fail bigint, leak_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.image_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.leak_test in ('minor_leak','fail'))::bigint
  from public.ureteroscope_qc_r3390 l
  group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3390_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3390_daily_qc_trend() to authenticated;

create or replace function public.founder_r3390_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ureteroscope_qc_capa_actions_r3390 c
  group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_capa_status_board() from public, anon;
grant execute on function public.founder_r3390_capa_status_board() to authenticated;

create or replace function public.founder_r3390_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ureteroscope_qc_capa_actions_r3390)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ureteroscope_qc_capa_actions_r3390 c
  group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3390_root_cause_pareto() to authenticated;

create or replace function public.founder_r3390_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ureteroscope_qc_capa_actions_r3390 c
  group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3390_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3390_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3390_high_risk_queue()
returns table(
  hospital_name text, scope_code text, device_type text, department text, check_date date,
  qc_verdict text, image_quality text, laser_fiber_transmission_ok text, fiber_tip_condition text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.scope_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.image_quality, l.laser_fiber_transmission_ok, l.fiber_tip_condition, l.notes
  from public.ureteroscope_qc_r3390 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.deflection_angle_ok = false
     or l.image_quality in ('degraded','fail')
     or l.channel_patency_ok = false
     or l.leak_test in ('minor_leak','fail')
     or l.laser_fiber_transmission_ok in ('degraded','fail')
     or l.fiber_tip_condition in ('burnt','frayed','replace_due')
     or l.sterilization_cycle_ok = false
     or l.reprocessing_traceable = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3390_high_risk_queue() from public, anon;
grant execute on function public.founder_r3390_high_risk_queue() to authenticated;
