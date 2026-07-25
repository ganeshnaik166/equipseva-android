-- Round 3398: Customer Hospital Retinal-Laser Photocoagulator & Ophthalmic Treatment-Laser QC Audit
-- Retinal laser QA — device type × department × power output × aiming beam × spot size × pattern alignment × fiber delivery × footswitch × safety filter × slit-lamp integration × CAPA

-- =============================================================================
-- TABLE 1: retinal_laser_qc_r3398 — per-device QC checks
-- =============================================================================
create table if not exists public.retinal_laser_qc_r3398 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'green_532nm_photocoagulator','yellow_577nm_laser','multispot_pattern_laser',
    'diode_810nm_laser','micropulse_laser','indirect_ophthalmoscope_laser'
  )),
  department text not null,
  check_date date not null,
  power_output_error_pct numeric(5,2),
  aiming_beam_ok boolean not null,
  spot_size_accuracy_ok boolean not null,
  pattern_alignment_ok text not null check (pattern_alignment_ok in (
    'ok','misaligned','fail','not_applicable'
  )),
  fiber_delivery_ok text not null check (fiber_delivery_ok in (
    'ok','degraded','fail','not_applicable'
  )),
  footswitch_ok boolean not null,
  safety_filter_ok boolean not null,
  slit_lamp_integration_ok boolean not null,
  safety_eyewear_available boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.retinal_laser_qc_r3398 enable row level security;

create index if not exists idx_retinal_laser_qc_r3398_org on public.retinal_laser_qc_r3398(organization_id);
create index if not exists idx_retinal_laser_qc_r3398_date on public.retinal_laser_qc_r3398(check_date);
create index if not exists idx_retinal_laser_qc_r3398_verdict on public.retinal_laser_qc_r3398(qc_verdict);

-- =============================================================================
-- TABLE 2: retinal_laser_qc_capa_actions_r3398 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.retinal_laser_qc_capa_actions_r3398 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.retinal_laser_qc_r3398(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'power_output_out_of_tolerance','aiming_beam_failure','spot_size_error','pattern_misalignment',
    'fiber_delivery_loss','footswitch_failure','safety_filter_failure',
    'slit_lamp_integration_fault','safety_eyewear_missing','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'laser_tube_aging','fiber_end_of_life','optics_misalignment','scanner_fault',
    'consumable_quality_issue','operator_setup_error','safety_interlock_fault',
    'pending_investigation','preventive_service_backlog','filter_degraded'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_power','replace_delivery_fiber','realign_optics','repair_scanner',
    'replace_safety_filter','provide_safety_eyewear','recalibrate','retrain_ophthalmology_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_laser_safety','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.retinal_laser_qc_capa_actions_r3398 enable row level security;

create index if not exists idx_retinal_laser_capa_r3398_log on public.retinal_laser_qc_capa_actions_r3398(qc_log_id);
create index if not exists idx_retinal_laser_capa_r3398_status on public.retinal_laser_qc_capa_actions_r3398(capa_status);

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

  insert into public.retinal_laser_qc_r3398 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    power_output_error_pct, aiming_beam_ok, spot_size_accuracy_ok, pattern_alignment_ok,
    fiber_delivery_ok, footswitch_ok, safety_filter_ok, slit_lamp_integration_ok,
    safety_eyewear_available, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.perr, q.aim, q.spot, q.pattern,
    q.fiber, q.foot, q.filter, q.slit,
    q.eyewear, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','RL-APL-01','green_532nm_photocoagulator','ophthalmology_ot','2026-07-03',
     1.2,true,true,'not_applicable','ok',true,true,true,true,true,'pass','Quarterly QC — 532nm photocoagulator power within tolerance'),
    ('Apollo Chennai','RL-APL-02','multispot_pattern_laser','ophthalmology_ot','2026-07-03',
     0.8,true,true,'ok','ok',true,true,true,true,true,'pass','Pattern laser alignment and delivery nominal'),
    ('Fortis Gurgaon','RL-FRT-11','yellow_577nm_laser','ophthalmology_opd','2026-07-02',
     2.6,true,true,'not_applicable','degraded',true,true,true,true,true,'conditional_pass','577nm power 2.6% off and fiber delivery degraded — recheck booked'),
    ('Fortis Gurgaon','RL-FRT-12','green_532nm_photocoagulator','ophthalmology_ot','2026-07-02',
     5.1,false,false,'not_applicable','fail',true,false,true,true,true,'fail','Power 5.1% off, aiming beam and safety filter failed — pulled'),
    ('Manipal Bengaluru','RL-MNP-21','diode_810nm_laser','ophthalmology_ot','2026-07-01',
     1.4,true,true,'not_applicable','ok',true,true,true,false,false,'conditional_pass','810nm ok but safety eyewear missing and calibration overdue'),
    ('Manipal Bengaluru','RL-MNP-22','micropulse_laser','ophthalmology_opd','2026-07-01',
     0.9,true,true,'not_applicable','ok',true,true,true,true,true,'pass','Micropulse laser QC nominal'),
    ('AIIMS Delhi','RL-AIM-31','multispot_pattern_laser','ophthalmology_ot','2026-06-30',
     1.1,true,true,'misaligned','ok',true,true,true,true,true,'conditional_pass','Pattern scanner slight misalignment — recalibrate scan'),
    ('AIIMS Delhi','RL-AIM-32','green_532nm_photocoagulator','ophthalmology_ot','2026-06-30',
     1.0,true,true,'not_applicable','ok',false,true,false,true,true,'fail','Footswitch intermittent and slit-lamp integration fault — pulled'),
    ('CMC Vellore','RL-CMC-41','yellow_577nm_laser','ophthalmology_ot','2026-06-29',
     0.7,true,true,'not_applicable','ok',true,true,true,true,true,'pass','577nm laser QC pass'),
    ('CMC Vellore','RL-CMC-42','diode_810nm_laser','ophthalmology_opd','2026-06-29',
     1.3,true,true,'not_applicable','degraded',true,true,true,true,false,'conditional_pass','810nm delivery fiber degraded and calibration overdue — plan fiber swap'),
    ('KIMS Hyderabad','RL-KIM-51','green_532nm_photocoagulator','ophthalmology_ot','2026-06-28',
     0.9,true,true,'not_applicable','ok',true,true,true,true,true,'pass','532nm photocoagulator QC pass post-AMC'),
    ('KIMS Hyderabad','RL-KIM-52','multispot_pattern_laser','ophthalmology_ot','2026-06-28',
     1.6,true,true,'ok','ok',true,true,true,true,true,'conditional_pass','Pattern laser power drift 1.6% within limit but trend up — monitor'),
    ('Yashoda Hyderabad','RL-YSH-61','micropulse_laser','ophthalmology_opd','2026-06-27',
     0.8,true,true,'not_applicable','ok',true,true,true,true,true,'pass','Micropulse laser QC nominal'),
    ('Kokilaben Mumbai','RL-KKB-71','green_532nm_photocoagulator','ophthalmology_ot','2026-06-27',
     6.4,false,false,'not_applicable','fail',false,false,false,false,false,'removed_from_service','Multiple failures across power, aiming, footswitch, filter — removed')
  ) as q(hosp, dcode, dtype, dept, cdate, perr, aim, spot, pattern, fiber, foot, filter, slit, eyewear, calcur, qv, nt);

  insert into public.retinal_laser_qc_capa_actions_r3398 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RL-FRT-12','power_output_out_of_tolerance','laser_tube_aging','recalibrate_power','in_progress','patient_safety_alert','2026-07-06',null,35000.00,'532nm power recalibration; aiming and filter checks after'),
    ('RL-MNP-21','safety_eyewear_missing','operator_setup_error','provide_safety_eyewear','open','aerb_laser_safety','2026-07-05',null,4000.00,'Wavelength-specific safety eyewear provisioned for 810nm'),
    ('RL-AIM-32','footswitch_failure','safety_interlock_fault','schedule_oem_service','escalated','patient_safety_alert','2026-07-04',null,18000.00,'Footswitch and slit-lamp integration fault escalated'),
    ('RL-KKB-71','power_output_out_of_tolerance','laser_tube_aging','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',52000.00,'Laser removed; tube replaced and revalidated'),
    ('RL-AIM-31','pattern_misalignment','scanner_fault','repair_scanner','verification_pending','internal_only','2026-07-05',null,22000.00,'Pattern scanner recalibrated — verify alignment next list'),
    ('RL-CMC-42','fiber_delivery_loss','fiber_end_of_life','replace_delivery_fiber','overdue','internal_only','2026-06-30',null,26000.00,'810nm delivery fiber replacement past target — vendor delay'),
    ('RL-FRT-11','fiber_delivery_loss','fiber_end_of_life','replace_delivery_fiber','open','none','2026-07-07',null,24000.00,'577nm fiber degradation — replacement ordered')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.retinal_laser_qc_r3398 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3398_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.retinal_laser_qc_r3398)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.retinal_laser_qc_r3398 l group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3398_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3398_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  power_issue bigint, safety_issue bigint, calibration_overdue bigint, pass_pct numeric
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
    count(*) filter (where l.power_output_error_pct > 2.0)::bigint,
    count(*) filter (where l.safety_filter_ok = false or l.safety_eyewear_available = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.retinal_laser_qc_r3398 l group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3398_hospital_scorecard() to authenticated;

create or replace function public.founder_r3398_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_power_error_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.power_output_error_pct), 2)
  from public.retinal_laser_qc_r3398 l group by l.device_type, l.department order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_device_department_matrix() from public, anon;
grant execute on function public.founder_r3398_device_department_matrix() to authenticated;

create or replace function public.founder_r3398_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, power_issue bigint, safety_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.power_output_error_pct > 2.0)::bigint,
    count(*) filter (where l.safety_filter_ok = false or l.safety_eyewear_available = false)::bigint
  from public.retinal_laser_qc_r3398 l group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3398_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3398_daily_qc_trend() to authenticated;

create or replace function public.founder_r3398_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.retinal_laser_qc_capa_actions_r3398 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_capa_status_board() from public, anon;
grant execute on function public.founder_r3398_capa_status_board() to authenticated;

create or replace function public.founder_r3398_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.retinal_laser_qc_capa_actions_r3398)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.retinal_laser_qc_capa_actions_r3398 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3398_root_cause_pareto() to authenticated;

create or replace function public.founder_r3398_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.retinal_laser_qc_capa_actions_r3398 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3398_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3398_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3398_high_risk_queue()
returns table(
  hospital_name text, device_code text, device_type text, department text, check_date date,
  qc_verdict text, power_output_error_pct numeric, fiber_delivery_ok text, pattern_alignment_ok text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.power_output_error_pct, l.fiber_delivery_ok, l.pattern_alignment_ok, l.notes
  from public.retinal_laser_qc_r3398 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.power_output_error_pct > 2.0
     or l.aiming_beam_ok = false
     or l.spot_size_accuracy_ok = false
     or l.pattern_alignment_ok in ('misaligned','fail')
     or l.fiber_delivery_ok in ('degraded','fail')
     or l.footswitch_ok = false
     or l.safety_filter_ok = false
     or l.safety_eyewear_available = false
     or l.slit_lamp_integration_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3398_high_risk_queue() from public, anon;
grant execute on function public.founder_r3398_high_risk_queue() to authenticated;
