-- Round 3246: Customer Hospital Surgical & Ophthalmic Medical-Laser Safety + Output QC Audit
-- Laser safety QA — laser type × output-power error × footswitch/door interlocks × aiming beam × safety eyewear × fume evacuation × LSO signoff × key control × CAPA

-- =============================================================================
-- TABLE 1: medical_laser_safety_r3246 — per-laser safety & output QC checks
-- =============================================================================
create table if not exists public.medical_laser_safety_r3246 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  laser_code text not null,
  laser_type text not null check (laser_type in (
    'co2_surgical','nd_yag_ophthalmic','argon_green','holmium_urology','diode_derm'
  )),
  department text not null,
  check_date date not null,
  output_power_error_pct numeric(5,2),
  aiming_beam_ok boolean not null,
  footswitch_interlock text not null check (footswitch_interlock in (
    'pass','fail','not_tested'
  )),
  door_interlock text not null check (door_interlock in (
    'pass','fail','bypassed'
  )),
  safety_eyewear_available boolean not null,
  fume_evacuator_ok text not null check (fume_evacuator_ok in (
    'ok','weak','missing','not_applicable'
  )),
  laser_safety_officer_signoff boolean not null,
  key_control_ok boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_laser_safety_r3246 enable row level security;

create index if not exists idx_medical_laser_r3246_org on public.medical_laser_safety_r3246(organization_id);
create index if not exists idx_medical_laser_r3246_date on public.medical_laser_safety_r3246(check_date);
create index if not exists idx_medical_laser_r3246_verdict on public.medical_laser_safety_r3246(qc_verdict);

-- =============================================================================
-- TABLE 2: medical_laser_safety_capa_actions_r3246 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.medical_laser_safety_capa_actions_r3246 (
  id uuid primary key default gen_random_uuid(),
  qc_check_id uuid not null references public.medical_laser_safety_r3246(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_power_deviation','door_interlock_failure','interlock_bypass_found',
    'footswitch_interlock_failure','aiming_beam_fault','fume_evacuation_gap',
    'eyewear_unavailable','key_control_lapse','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'laser_cavity_degradation','power_meter_uncalibrated','interlock_relay_failed',
    'interlock_switch_worn','interlock_deliberately_bypassed','aiming_diode_ageing',
    'evacuator_filter_clogged','eyewear_stock_gap','key_custody_lapse',
    'training_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output_power','replace_resonator_or_cavity','replace_interlock_relay',
    'replace_footswitch_assembly','restore_door_interlock','replace_aiming_diode',
    'replace_evacuator_filter','procure_certified_eyewear','enforce_key_custody_log',
    'retrain_ot_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_laser_safety_capa_actions_r3246 enable row level security;

create index if not exists idx_laser_capa_r3246_check on public.medical_laser_safety_capa_actions_r3246(qc_check_id);
create index if not exists idx_laser_capa_r3246_status on public.medical_laser_safety_capa_actions_r3246(capa_status);

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

  -- 14 laser QC check rows
  insert into public.medical_laser_safety_r3246 (
    organization_id, hospital_name, laser_code, laser_type, department,
    check_date, output_power_error_pct, aiming_beam_ok,
    footswitch_interlock, door_interlock, safety_eyewear_available,
    fume_evacuator_ok, laser_safety_officer_signoff, key_control_ok,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ltype, q.dept,
    q.cdate::date, q.perr, q.abeam,
    q.fsw, q.dint, q.eyew,
    q.fume, q.lso, q.keyc,
    q.qv, q.nt
  from (values
    ('Apollo Hospitals Chennai Greams Road','LSR-APL-001','co2_surgical','ENT & Head-Neck OT','2026-07-03',
     2.40,true,'pass','pass',true,'ok',true,true,'pass','Quarterly output check — 2.4% error well within tolerance'),
    ('Apollo Hospitals Chennai Greams Road','LSR-APL-002','holmium_urology','Urology OT','2026-07-03',
     -24.60,true,'pass','pass',true,'not_applicable',true,true,'conditional_pass','Output 24.6% below set energy — cavity ageing, recalibration booked'),
    ('Fortis Memorial Research Institute Gurgaon','LSR-FRT-101','nd_yag_ophthalmic','Ophthalmology Laser Room','2026-07-02',
     3.10,true,'pass','bypassed',true,'not_applicable',false,true,'fail','Door interlock found taped over — LSO signoff withheld'),
    ('Fortis Memorial Research Institute Gurgaon','LSR-FRT-102','diode_derm','Dermatology Laser Suite','2026-07-02',
     5.80,true,'pass','pass',false,'weak',true,true,'conditional_pass','Only one certified goggle pair for staff of three; evacuator suction weak'),
    ('Manipal Hospital Old Airport Road Bengaluru','LSR-MNP-201','co2_surgical','Gynaecology OT','2026-07-01',
     1.90,true,'pass','pass',true,'ok',true,true,'pass','Annual QC clean pass — verified by BME Rakesh Iyer'),
    ('Manipal Hospital Old Airport Road Bengaluru','LSR-MNP-202','argon_green','Retina Laser Room','2026-07-01',
     8.70,false,'pass','pass',true,'not_applicable',true,true,'conditional_pass','Aiming beam dim on slit-lamp adapter — diode replacement due'),
    ('AIIMS New Delhi','LSR-AIM-301','holmium_urology','Urology OT-4','2026-06-30',
     -31.50,true,'fail','pass',true,'not_applicable',false,true,'removed_from_service','Footswitch fired in standby during test; output 31.5% low — unit pulled'),
    ('AIIMS New Delhi','LSR-AIM-302','nd_yag_ophthalmic','RP Centre Laser Room','2026-06-30',
     2.20,true,'pass','pass',true,'not_applicable',true,true,'pass','Capsulotomy energy check within 5%'),
    ('CMC Vellore','LSR-CMC-401','co2_surgical','Plastic Surgery OT','2026-06-29',
     4.30,true,'not_tested','pass',true,'missing',true,false,'conditional_pass','Fume evacuator missing from OT; console key found unattended'),
    ('CMC Vellore','LSR-CMC-402','diode_derm','Dermatology OPD','2026-06-29',
     6.10,true,'pass','pass',true,'ok',true,true,'pass','Output within tolerance after AMC service by Arvind Kulkarni'),
    ('KIMS Hospitals Secunderabad','LSR-KIM-501','holmium_urology','Urology OT-2','2026-06-28',
     12.40,true,'pass','fail',true,'not_applicable',true,true,'fail','Door interlock relay dead — laser fires with door open'),
    ('KIMS Hospitals Secunderabad','LSR-KIM-502','argon_green','Ophthalmology Laser Room','2026-06-28',
     2.80,true,'pass','pass',true,'not_applicable',true,true,'pass','Green photocoagulator output nominal'),
    ('Sankara Nethralaya Chennai','LSR-SNK-601','nd_yag_ophthalmic','YAG Laser Room 2','2026-06-27',
     18.90,true,'pass','pass',false,'not_applicable',true,true,'conditional_pass','Attendant eyewear set out for recoating — spare pair ordered'),
    ('LV Prasad Eye Institute Hyderabad','LSR-LVP-701','argon_green','Retina Laser Suite','2026-06-27',
     1.40,true,'pass','pass',true,'not_applicable',true,true,'pass','Six-monthly power audit clean')
  ) as q(hosp, code, ltype, dept, cdate, perr, abeam, fsw, dint, eyew, fume, lso, keyc, qv, nt);

  -- CAPA seed — attach to specific checks via laser code
  insert into public.medical_laser_safety_capa_actions_r3246 (
    qc_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('LSR-FRT-101','interlock_bypass_found','interlock_deliberately_bypassed','restore_door_interlock','escalated','patient_safety_alert','2026-07-06',null,8000.00,'Tape removed on the spot; incident escalated to medical director'),
    ('LSR-AIM-301','footswitch_interlock_failure','interlock_switch_worn','replace_footswitch_assembly','in_progress','aerb_notifiable','2026-07-10',null,145000.00,'Footswitch assembly plus resonator service quoted by OEM'),
    ('LSR-KIM-501','door_interlock_failure','interlock_relay_failed','replace_interlock_relay','open','nabh_finding','2026-07-08',null,22000.00,'Relay on order; laser locked out until fitted'),
    ('LSR-APL-002','output_power_deviation','laser_cavity_degradation','recalibrate_output_power','verification_pending','iso_13485_deviation','2026-07-05',null,60000.00,'Recalibrated by service engineer Suresh Menon — verify at next OT list'),
    ('LSR-CMC-401','fume_evacuation_gap','evacuator_filter_clogged','replace_evacuator_filter','closed','internal_only','2026-07-02','2026-06-30',9500.00,'ULPA filter replaced; key custody log restarted'),
    ('LSR-MNP-202','aiming_beam_fault','aiming_diode_ageing','replace_aiming_diode','open','internal_only','2026-07-12',null,18500.00,'Aiming diode module ordered from OEM'),
    ('LSR-FRT-102','eyewear_unavailable','eyewear_stock_gap','procure_certified_eyewear','overdue','nabh_finding','2026-06-25',null,14000.00,'OD 5+ goggles past target date — purchase pending approval')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.medical_laser_safety_r3246 e
    on e.organization_id = v_org_id and e.laser_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3246_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_laser_safety_r3246)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.medical_laser_safety_r3246 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3246_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level laser-safety scorecard
create or replace function public.founder_r3246_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  interlock_issues bigint,
  eyewear_gaps bigint,
  lso_signoff_missing bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.footswitch_interlock = 'fail' or l.door_interlock in ('fail','bypassed'))::bigint,
    count(*) filter (where not l.safety_eyewear_available)::bigint,
    count(*) filter (where not l.laser_safety_officer_signoff)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.medical_laser_safety_r3246 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3246_hospital_scorecard() to authenticated;

-- 3) Laser type × department matrix
create or replace function public.founder_r3246_laser_type_department_matrix()
returns table(laser_type text, department text, checks bigint, passed bigint, avg_output_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.laser_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.output_power_error_pct), 2)
  from public.medical_laser_safety_r3246 l
  group by l.laser_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_laser_type_department_matrix() from public, anon;
grant execute on function public.founder_r3246_laser_type_department_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3246_daily_check_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, interlock_issues bigint, eyewear_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.footswitch_interlock = 'fail' or l.door_interlock in ('fail','bypassed'))::bigint,
    count(*) filter (where not l.safety_eyewear_available)::bigint
  from public.medical_laser_safety_r3246 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3246_daily_check_trend() from public, anon;
grant execute on function public.founder_r3246_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3246_capa_status_board()
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
  from public.medical_laser_safety_capa_actions_r3246 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_capa_status_board() from public, anon;
grant execute on function public.founder_r3246_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3246_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_laser_safety_capa_actions_r3246)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.medical_laser_safety_capa_actions_r3246 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3246_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3246_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.medical_laser_safety_capa_actions_r3246 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3246_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3246_regulatory_impact_digest() to authenticated;

-- 8) High-risk laser queue (top individual concerns)
create or replace function public.founder_r3246_high_risk_queue()
returns table(
  hospital_name text,
  laser_code text,
  laser_type text,
  department text,
  check_date date,
  qc_verdict text,
  footswitch_interlock text,
  door_interlock text,
  fume_evacuator_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.laser_code, l.laser_type, l.department, l.check_date,
    l.qc_verdict, l.footswitch_interlock, l.door_interlock, l.fume_evacuator_ok, l.notes
  from public.medical_laser_safety_r3246 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.footswitch_interlock = 'fail'
     or l.door_interlock in ('fail','bypassed')
     or not l.safety_eyewear_available
     or l.fume_evacuator_ok in ('weak','missing')
     or not l.laser_safety_officer_signoff
     or not l.key_control_ok
     or not l.aiming_beam_ok
     or abs(l.output_power_error_pct) > 10
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3246_high_risk_queue() from public, anon;
grant execute on function public.founder_r3246_high_risk_queue() to authenticated;
