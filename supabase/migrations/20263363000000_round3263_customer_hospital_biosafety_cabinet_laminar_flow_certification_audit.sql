-- Round 3263: Customer Hospital Biosafety-Cabinet, Laminar-Flow Hood & Cytotoxic-Isolator Certification Audit
-- BSC/LAF cert QA — cabinet type × downflow/inflow velocity × HEPA DOP/PAO leak × particle ISO class × smoke pattern × UV lamp × sash interlock × cert verdict × CAPA

-- =============================================================================
-- TABLE 1: biosafety_cabinet_r3263 — individual cabinet / hood certification checks
-- =============================================================================
create table if not exists public.biosafety_cabinet_r3263 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  cabinet_code text not null,
  cabinet_type text not null check (cabinet_type in (
    'bsc_class_ii_a2','bsc_class_ii_b2','horizontal_laminar_flow','vertical_laminar_flow','cytotoxic_isolator','clean_bench'
  )),
  department text not null,
  check_date date not null,
  checked_at timestamptz not null,
  downflow_velocity_ok boolean not null,
  inflow_velocity_ms numeric(4,2),
  hepa_filter_leak_test text not null check (hepa_filter_leak_test in (
    'pass','repair_seal','fail'
  )),
  particle_count_iso_class text not null check (particle_count_iso_class in (
    'iso5','iso6','iso7','out_of_spec'
  )),
  airflow_alarm_ok boolean not null,
  uv_lamp_hours int not null,
  smoke_pattern_test text not null check (smoke_pattern_test in (
    'pass','turbulent','fail','not_done'
  )),
  sash_interlock_ok boolean not null,
  cert_valid_until date,
  cert_verdict text not null check (cert_verdict in (
    'certified_pass','conditional','failed','decertified'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biosafety_cabinet_r3263 enable row level security;

create index if not exists idx_biosafety_cabinet_r3263_org on public.biosafety_cabinet_r3263(organization_id);
create index if not exists idx_biosafety_cabinet_r3263_date on public.biosafety_cabinet_r3263(check_date);
create index if not exists idx_biosafety_cabinet_r3263_verdict on public.biosafety_cabinet_r3263(cert_verdict);

-- =============================================================================
-- TABLE 2: biosafety_cabinet_capa_actions_r3263 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.biosafety_cabinet_capa_actions_r3263 (
  id uuid primary key default gen_random_uuid(),
  cert_log_id uuid not null references public.biosafety_cabinet_r3263(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'hepa_leak','downflow_velocity_deviation','inflow_velocity_deviation','particle_count_excursion',
    'smoke_pattern_turbulence','airflow_alarm_failure','sash_interlock_failure','uv_lamp_expired','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'hepa_filter_loaded','filter_seal_leak','blower_motor_worn','damper_misadjusted',
    'prefilter_clogged','sensor_calibration_drift','interlock_switch_faulty','uv_lamp_end_of_life',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hepa_filter','reseal_filter_gasket','replace_blower_motor','readjust_damper_balance',
    'replace_prefilter','recalibrate_sensors','replace_interlock_switch','replace_uv_lamp',
    'decertify_and_tag_out','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_14644_deviation','usp_800_deviation','staff_exposure_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biosafety_cabinet_capa_actions_r3263 enable row level security;

create index if not exists idx_biosafety_capa_r3263_log on public.biosafety_cabinet_capa_actions_r3263(cert_log_id);
create index if not exists idx_biosafety_capa_r3263_status on public.biosafety_cabinet_capa_actions_r3263(capa_status);

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

  -- 14 cabinet certification rows
  insert into public.biosafety_cabinet_r3263 (
    organization_id, hospital_name, cabinet_code, cabinet_type, department,
    check_date, checked_at, downflow_velocity_ok, inflow_velocity_ms, hepa_filter_leak_test,
    particle_count_iso_class, airflow_alarm_ok, uv_lamp_hours, smoke_pattern_test, sash_interlock_ok,
    cert_valid_until, cert_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ctype, q.dept,
    q.cdate::date, q.cat::timestamptz, q.dvo, q.ivms, q.hplt,
    q.pcic, q.aao, q.uvh, q.spt, q.sio,
    q.cvu::date, q.cv, q.nt
  from (values
    ('Apollo Chennai Greams Road','BSC-APL-01','bsc_class_ii_a2','Microbiology','2026-07-05','2026-07-05 07:20:00+05:30',
     true,0.53,'pass','iso5',true,4200,'pass',true,'2027-07-05','certified_pass','Annual certification — all parameters within NSF 49 limits'),
    ('Apollo Chennai Greams Road','ISO-APL-02','cytotoxic_isolator','Oncology Chemo Prep','2026-07-05','2026-07-05 08:10:00+05:30',
     true,0.48,'pass','iso5',true,3100,'pass',true,'2027-07-05','certified_pass','USP 800 isolator — negative pressure & inflow verified'),
    ('Fortis Gurgaon','BSC-FRT-11','bsc_class_ii_b2','Pharmacy IV Admixture','2026-07-04','2026-07-04 06:50:00+05:30',
     false,0.38,'repair_seal','iso6',true,5200,'turbulent',true,null,'conditional','Downflow low & minor gasket leak — reseal then re-cert'),
    ('Fortis Gurgaon','LAF-FRT-12','horizontal_laminar_flow','Microbiology','2026-07-04','2026-07-04 07:40:00+05:30',
     true,0.45,'fail','out_of_spec',true,6100,'fail',true,null,'failed','HEPA DOP leak above 0.01 pct and particle out of spec — decert pending'),
    ('Manipal Bengaluru Old Airport Road','BSC-MNP-21','vertical_laminar_flow','Sterile Compounding','2026-07-03','2026-07-03 08:05:00+05:30',
     true,0.51,'pass','iso5',true,2800,'pass',true,'2027-07-03','certified_pass','Routine re-certification pass'),
    ('Manipal Bengaluru Old Airport Road','ISO-MNP-22','cytotoxic_isolator','Oncology Chemo Prep','2026-07-03','2026-07-03 09:00:00+05:30',
     true,0.42,'pass','iso6',false,3400,'pass',true,'2027-07-03','conditional','Airflow alarm not annunciating on test — alarm board flagged'),
    ('AIIMS New Delhi Ansari Nagar','BSC-AIM-31','bsc_class_ii_a2','TB Microbiology','2026-07-02','2026-07-02 06:30:00+05:30',
     true,0.50,'pass','iso5',true,4900,'pass',true,'2027-07-02','certified_pass','BSL-3 TB lab cabinet certified'),
    ('AIIMS New Delhi Ansari Nagar','LAF-AIM-32','horizontal_laminar_flow','Media Preparation','2026-07-02','2026-07-02 07:20:00+05:30',
     true,0.35,'pass','iso7',true,8200,'turbulent',true,null,'conditional','Inflow low, UV lamp past 8000h — lamp replace & rebalance'),
    ('CMC Vellore','BSC-CMC-41','bsc_class_ii_b2','Virology','2026-07-01','2026-07-01 06:45:00+05:30',
     false,0.30,'fail','out_of_spec',true,7600,'fail',false,null,'decertified','Multiple failures — cabinet tagged out of service'),
    ('CMC Vellore','CB-CMC-42','clean_bench','Tissue Culture','2026-07-01','2026-07-01 07:35:00+05:30',
     true,null,'pass','iso5',true,1200,'pass',true,'2027-07-01','certified_pass','Clean bench (product protection only) certified'),
    ('KIMS Hyderabad Kondapur','ISO-KIM-51','cytotoxic_isolator','Oncology Chemo Prep','2026-06-30','2026-06-30 08:15:00+05:30',
     true,0.44,'repair_seal','iso6',true,3900,'pass',true,null,'conditional','Glove-port gasket seep — reseal & leak re-test'),
    ('Nova IVF Mumbai','LAF-NOV-61','vertical_laminar_flow','Embryology','2026-06-30','2026-06-30 09:10:00+05:30',
     true,0.49,'pass','iso5',true,2100,'pass',true,'2027-06-30','certified_pass','IVF vertical LAF certified ISO 5'),
    ('Cloudnine Bengaluru Jayanagar','BSC-CLD-71','bsc_class_ii_a2','NICU Milk Bank','2026-06-29','2026-06-29 07:05:00+05:30',
     true,0.52,'pass','iso5',true,3300,'pass',true,'2027-06-29','certified_pass','Human milk bank BSC certified'),
    ('Rainbow Children''s Hyderabad','ISO-RBW-81','cytotoxic_isolator','Paediatric Oncology','2026-06-29','2026-06-29 08:00:00+05:30',
     false,0.40,'pass','iso7',false,4600,'turbulent',false,null,'failed','Downflow low, alarm & sash interlock fail — cert withheld')
  ) as q(hosp, code, ctype, dept, cdate, cat, dvo, ivms, hplt, pcic, aao, uvh, spt, sio, cvu, cv, nt);

  -- CAPA seed — attach to specific cabinets via cabinet_code
  insert into public.biosafety_cabinet_capa_actions_r3263 (
    cert_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('LAF-FRT-12','hepa_leak','filter_seal_leak','replace_hepa_filter','escalated','cdsco_notifiable','2026-07-10',null,85000.00,'HEPA DOP leak — filter replacement ordered from OEM'),
    ('BSC-FRT-11','downflow_velocity_deviation','damper_misadjusted','readjust_damper_balance','in_progress','iso_14644_deviation','2026-07-09',null,15000.00,'Damper rebalanced, gasket reseal pending re-cert'),
    ('ISO-MNP-22','airflow_alarm_failure','sensor_calibration_drift','recalibrate_sensors','open','usp_800_deviation','2026-07-08',null,12000.00,'Alarm board sensor recalibration scheduled'),
    ('LAF-AIM-32','uv_lamp_expired','uv_lamp_end_of_life','replace_uv_lamp','closed','internal_only','2026-07-05','2026-07-04',6500.00,'UV lamp replaced at 8200h, inflow rebalanced'),
    ('BSC-CMC-41','hepa_leak','blower_motor_worn','replace_blower_motor','escalated','staff_exposure_alert','2026-07-06',null,140000.00,'Decertified — blower & HEPA replacement, staff exposure review'),
    ('ISO-KIM-51','hepa_leak','filter_seal_leak','reseal_filter_gasket','verification_pending','usp_800_deviation','2026-07-07',null,9000.00,'Glove-port gasket resealed — awaiting leak re-test'),
    ('ISO-RBW-81','sash_interlock_failure','interlock_switch_faulty','replace_interlock_switch','overdue','usp_800_deviation','2026-06-28',null,22000.00,'Interlock switch on order — past target, cabinet tagged out')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.biosafety_cabinet_r3263 e
    on e.organization_id = v_org_id and e.cabinet_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Certification verdict distribution
create or replace function public.founder_r3263_cert_verdict_rollup()
returns table(cert_verdict text, cabinets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biosafety_cabinet_r3263)
  select l.cert_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.biosafety_cabinet_r3263 l
  group by l.cert_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_cert_verdict_rollup() from public, anon;
grant execute on function public.founder_r3263_cert_verdict_rollup() to authenticated;

-- 2) Hospital-level certification scorecard
create or replace function public.founder_r3263_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  certified bigint,
  conditional bigint,
  failed bigint,
  hepa_leak_fail bigint,
  particle_out_of_spec bigint,
  smoke_fail bigint,
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
    count(*) filter (where l.cert_verdict = 'certified_pass')::bigint,
    count(*) filter (where l.cert_verdict = 'conditional')::bigint,
    count(*) filter (where l.cert_verdict in ('failed','decertified'))::bigint,
    count(*) filter (where l.hepa_filter_leak_test in ('repair_seal','fail'))::bigint,
    count(*) filter (where l.particle_count_iso_class = 'out_of_spec')::bigint,
    count(*) filter (where l.smoke_pattern_test in ('turbulent','fail'))::bigint,
    round(100.0 * count(*) filter (where l.cert_verdict = 'certified_pass')::numeric / nullif(count(*),0), 1)
  from public.biosafety_cabinet_r3263 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3263_hospital_scorecard() to authenticated;

-- 3) Cabinet type × particle ISO class matrix
create or replace function public.founder_r3263_cabinet_type_iso_matrix()
returns table(cabinet_type text, particle_count_iso_class text, cabinets bigint, certified bigint, avg_inflow_velocity_ms numeric, avg_uv_lamp_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cabinet_type, l.particle_count_iso_class, count(*)::bigint,
    count(*) filter (where l.cert_verdict = 'certified_pass')::bigint,
    round(avg(l.inflow_velocity_ms), 2),
    round(avg(l.uv_lamp_hours), 0)
  from public.biosafety_cabinet_r3263 l
  group by l.cabinet_type, l.particle_count_iso_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_cabinet_type_iso_matrix() from public, anon;
grant execute on function public.founder_r3263_cabinet_type_iso_matrix() to authenticated;

-- 4) Daily certification trend
create or replace function public.founder_r3263_daily_cert_trend()
returns table(check_date date, checks bigint, certified bigint, failed bigint, hepa_leak_fail bigint, particle_out_of_spec bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.cert_verdict = 'certified_pass')::bigint,
    count(*) filter (where l.cert_verdict in ('failed','decertified'))::bigint,
    count(*) filter (where l.hepa_filter_leak_test in ('repair_seal','fail'))::bigint,
    count(*) filter (where l.particle_count_iso_class = 'out_of_spec')::bigint
  from public.biosafety_cabinet_r3263 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3263_daily_cert_trend() from public, anon;
grant execute on function public.founder_r3263_daily_cert_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3263_capa_status_board()
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
  from public.biosafety_cabinet_capa_actions_r3263 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_capa_status_board() from public, anon;
grant execute on function public.founder_r3263_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3263_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biosafety_cabinet_capa_actions_r3263)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.biosafety_cabinet_capa_actions_r3263 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3263_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3263_regulatory_impact_digest()
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
  from public.biosafety_cabinet_capa_actions_r3263 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3263_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3263_regulatory_impact_digest() to authenticated;

-- 8) High-risk certification queue (top individual concerns)
create or replace function public.founder_r3263_high_risk_queue()
returns table(
  hospital_name text,
  cabinet_code text,
  cabinet_type text,
  check_date date,
  cert_verdict text,
  hepa_filter_leak_test text,
  particle_count_iso_class text,
  smoke_pattern_test text,
  cert_valid_until date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.cabinet_code, l.cabinet_type, l.check_date,
    l.cert_verdict, l.hepa_filter_leak_test, l.particle_count_iso_class, l.smoke_pattern_test,
    l.cert_valid_until, l.notes
  from public.biosafety_cabinet_r3263 l
  where l.cert_verdict in ('conditional','failed','decertified')
     or l.hepa_filter_leak_test in ('repair_seal','fail')
     or l.particle_count_iso_class = 'out_of_spec'
     or l.smoke_pattern_test in ('turbulent','fail')
     or l.downflow_velocity_ok = false
     or l.airflow_alarm_ok = false
     or l.sash_interlock_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3263_high_risk_queue() from public, anon;
grant execute on function public.founder_r3263_high_risk_queue() to authenticated;
