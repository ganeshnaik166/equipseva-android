-- Round 3347: Customer Hospital ETO & H2O2 Gas-Plasma Low-Temperature Sterilizer QC Audit
-- Low-temp sterilization QA — sterilizer type × department × biological-indicator × chemical-indicator × ETO residual aeration × plasma cassette stock × chamber leak × temp/pressure profile × load release × exhaust scrubber × CAPA

-- =============================================================================
-- TABLE 1: lowtemp_sterilizer_r3347 — per-cycle/machine low-temp sterilizer QC checks
-- =============================================================================
create table if not exists public.lowtemp_sterilizer_r3347 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  machine_code text not null,
  sterilizer_type text not null check (sterilizer_type in (
    'eto_sterilizer','h2o2_gas_plasma','h2o2_vapor','ozone_sterilizer'
  )),
  department text not null,
  check_date date not null,
  cycle_count_today int not null,
  biological_indicator_result text not null check (biological_indicator_result in (
    'pass','fail','pending','not_run'
  )),
  chemical_indicator_ok boolean not null,
  eto_residual_aeration_ok text not null check (eto_residual_aeration_ok in (
    'ok','insufficient','not_applicable'
  )),
  plasma_cassette_stock text not null check (plasma_cassette_stock in (
    'adequate','low','empty','not_applicable'
  )),
  chamber_leak_test text not null check (chamber_leak_test in (
    'pass','fail','not_done'
  )),
  temperature_pressure_profile_ok boolean not null,
  load_release_documented boolean not null,
  exhaust_scrubber_ok text not null check (exhaust_scrubber_ok in (
    'ok','fault','not_applicable'
  )),
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lowtemp_sterilizer_r3347 enable row level security;

create index if not exists idx_lowtemp_sterilizer_r3347_org on public.lowtemp_sterilizer_r3347(organization_id);
create index if not exists idx_lowtemp_sterilizer_r3347_date on public.lowtemp_sterilizer_r3347(check_date);
create index if not exists idx_lowtemp_sterilizer_r3347_verdict on public.lowtemp_sterilizer_r3347(audit_verdict);

-- =============================================================================
-- TABLE 2: lowtemp_sterilizer_capa_actions_r3347 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lowtemp_sterilizer_capa_actions_r3347 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.lowtemp_sterilizer_r3347(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'biological_indicator_failure','chemical_indicator_failure','eto_residual_aeration','plasma_cassette_stockout',
    'chamber_leak','temp_pressure_profile','load_release_documentation','exhaust_scrubber_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'door_gasket_leak','vacuum_pump_degraded','cassette_supply_chain','sterilant_injection_fault',
    'aeration_cycle_too_short','bi_incubator_fault','operator_loading_error','scrubber_media_exhausted',
    'software_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_door_gasket','service_vacuum_pump','replenish_cassette_stock','service_sterilant_injector',
    'extend_aeration_cycle','replace_bi_incubator','retrain_cssd_staff','replace_scrubber_media',
    'update_cycle_config','requarantine_and_reprocess','remove_from_service','schedule_oem_service','none_required'
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

alter table public.lowtemp_sterilizer_capa_actions_r3347 enable row level security;

create index if not exists idx_lowtemp_capa_r3347_log on public.lowtemp_sterilizer_capa_actions_r3347(qc_log_id);
create index if not exists idx_lowtemp_capa_r3347_status on public.lowtemp_sterilizer_capa_actions_r3347(capa_status);

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

  -- 14 low-temp sterilizer QC rows
  insert into public.lowtemp_sterilizer_r3347 (
    organization_id, hospital_name, machine_code, sterilizer_type, department,
    check_date, cycle_count_today, biological_indicator_result, chemical_indicator_ok,
    eto_residual_aeration_ok, plasma_cassette_stock, chamber_leak_test,
    temperature_pressure_profile_ok, load_release_documented, exhaust_scrubber_ok,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.mc, q.stype, q.dept,
    q.cd::date, q.cyc::int, q.bi, q.ci,
    q.eto, q.cass, q.leak,
    q.tpp, q.lrd, q.exh,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','STE-APL-01','eto_sterilizer','CSSD','2026-07-03',4,'pass',true,'ok','not_applicable','pass',true,true,'ok','pass','ETO cycle BI negative at 48h readout — full load release documented'),
    ('Apollo Chennai Greams Road','STE-APL-02','h2o2_gas_plasma','CSSD','2026-07-03',9,'pass',true,'not_applicable','adequate','pass',true,true,'not_applicable','pass','STERRAD 100NX daily BI pass — cassette stock full'),
    ('Fortis Gurgaon','STE-FRT-01','eto_sterilizer','CSSD','2026-07-02',3,'pass',true,'insufficient','not_applicable','pass',true,true,'ok','conditional_pass','Aeration cut short on last load — residual re-check ordered'),
    ('Fortis Gurgaon','STE-FRT-02','h2o2_gas_plasma','Endoscopy','2026-07-02',6,'pass',true,'not_applicable','low','pass',true,true,'not_applicable','conditional_pass','Cassette stock low — reorder placed, two cycles remaining'),
    ('Manipal Bengaluru Old Airport Road','STE-MNP-01','eto_sterilizer','CSSD','2026-07-01',2,'fail',true,'ok','not_applicable','pass',true,false,'ok','quarantined','BI positive at 48h — entire load recalled and quarantined'),
    ('Manipal Bengaluru Old Airport Road','STE-MNP-02','h2o2_vapor','OT Sterile Store','2026-06-30',5,'pass',false,'not_applicable','not_applicable','fail',false,false,'not_applicable','fail','Chamber leak test failed and CI colour-shift incomplete — service raised'),
    ('AIIMS Delhi Ansari Nagar','STE-AIM-01','eto_sterilizer','CSSD','2026-06-30',4,'pass',true,'ok','not_applicable','pass',true,true,'ok','pass','Monthly ETO BI challenge negative — scrubber effluent within limit'),
    ('AIIMS Delhi Ansari Nagar','STE-AIM-02','h2o2_gas_plasma','Cath Lab CSSD','2026-06-29',0,'not_run',false,'not_applicable','empty','not_done',false,false,'not_applicable','fail','Cassette empty — no cycles run, load release blocked pending restock'),
    ('CMC Vellore','STE-CMC-01','eto_sterilizer','CSSD','2026-06-29',3,'pending',true,'ok','not_applicable','pass',true,false,'ok','conditional_pass','BI incubating — load held in quarantine store until 48h readout'),
    ('CMC Vellore','STE-CMC-02','ozone_sterilizer','Ophthalmology','2026-06-28',7,'pass',true,'not_applicable','not_applicable','pass',true,true,'ok','pass','Ozone cycle BI negative — profile within spec'),
    ('KIMS Hyderabad Kondapur','STE-KIM-01','eto_sterilizer','CSSD','2026-06-28',2,'pass',true,'ok','not_applicable','pass',true,true,'fault','conditional_pass','ETO exhaust scrubber alarm — abatement media near exhaustion'),
    ('KIMS Hyderabad Kondapur','STE-KIM-02','h2o2_gas_plasma','Endoscopy','2026-06-27',8,'pass',true,'not_applicable','adequate','pass',true,true,'not_applicable','pass','Daily STERRAD QC pass — all indicators nominal'),
    ('Medanta Gurgaon','STE-MED-01','eto_sterilizer','CSSD','2026-06-27',1,'fail',false,'insufficient','not_applicable','fail',false,false,'ok','quarantined','Door gasket leak — vacuum hold failed, BI positive, load quarantined'),
    ('Kokilaben Mumbai Andheri','STE-KKB-01','h2o2_gas_plasma','Robotic Surgery CSSD','2026-06-26',6,'pass',true,'not_applicable','adequate','pass',true,true,'not_applicable','pass',null)
  ) as q(hosp, mc, stype, dept, cd, cyc, bi, ci, eto, cass, leak, tpp, lrd, exh, verdict, nt);

  -- CAPA seed — attach to specific checks via machine_code
  insert into public.lowtemp_sterilizer_capa_actions_r3347 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('STE-MNP-01','biological_indicator_failure','sterilant_injection_fault','service_sterilant_injector','escalated','patient_safety_alert','2026-07-05',null,55000.00,'BI positive — full load quarantined, sterilant injector service escalated to OEM'),
    ('STE-MNP-02','chamber_leak','door_gasket_leak','replace_door_gasket','in_progress','nabh_finding','2026-07-04',null,16000.00,'Chamber leak and CI incomplete — door gasket replacement in progress'),
    ('STE-AIM-02','plasma_cassette_stockout','cassette_supply_chain','replenish_cassette_stock','open','internal_only','2026-07-06',null,24000.00,'STERRAD cassette empty — emergency restock ordered from ASP'),
    ('STE-KIM-01','exhaust_scrubber_fault','scrubber_media_exhausted','replace_scrubber_media','overdue','cdsco_notifiable','2026-06-30',null,38000.00,'ETO abatement media exhausted — replacement past target date'),
    ('STE-MED-01','chamber_leak','door_gasket_leak','replace_door_gasket','closed','iso_13485_deviation','2026-06-30','2026-06-29',21000.00,'Door gasket replaced and vacuum hold re-verified — load reprocessed'),
    ('STE-FRT-01','eto_residual_aeration','aeration_cycle_too_short','extend_aeration_cycle','verification_pending','internal_only','2026-07-05',null,4500.00,'Aeration cycle extended to 12h — residual re-test pending'),
    ('STE-CMC-01','biological_indicator_failure','bi_incubator_fault','replace_bi_incubator','open','nabh_finding','2026-07-02',null,9000.00,'BI incubator temperature unstable — readout delayed, incubator swapped')
  ) as q(mc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.lowtemp_sterilizer_r3347 e
    on e.organization_id = v_org_id and e.machine_code = q.mc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3347_audit_verdict_rollup()
returns table(audit_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lowtemp_sterilizer_r3347)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lowtemp_sterilizer_r3347 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3347_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3347_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  bi_fail bigint,
  chamber_leak_fail bigint,
  quarantined bigint,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.audit_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.biological_indicator_result = 'fail')::bigint,
    count(*) filter (where l.chamber_leak_test = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'quarantined')::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.lowtemp_sterilizer_r3347 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3347_hospital_scorecard() to authenticated;

-- 3) Sterilizer type × department matrix
create or replace function public.founder_r3347_type_department_matrix()
returns table(sterilizer_type text, department text, checks bigint, passed bigint, total_cycles bigint, bi_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sterilizer_type, l.department, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    coalesce(sum(l.cycle_count_today),0)::bigint,
    count(*) filter (where l.biological_indicator_result = 'fail')::bigint
  from public.lowtemp_sterilizer_r3347 l
  group by l.sterilizer_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_type_department_matrix() from public, anon;
grant execute on function public.founder_r3347_type_department_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3347_daily_check_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, bi_fail bigint, chamber_leak_fail bigint, total_cycles bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.biological_indicator_result = 'fail')::bigint,
    count(*) filter (where l.chamber_leak_test = 'fail')::bigint,
    coalesce(sum(l.cycle_count_today),0)::bigint
  from public.lowtemp_sterilizer_r3347 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3347_daily_check_trend() from public, anon;
grant execute on function public.founder_r3347_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3347_capa_status_board()
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
  from public.lowtemp_sterilizer_capa_actions_r3347 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_capa_status_board() from public, anon;
grant execute on function public.founder_r3347_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3347_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lowtemp_sterilizer_capa_actions_r3347)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lowtemp_sterilizer_capa_actions_r3347 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3347_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3347_regulatory_impact_digest()
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
  from public.lowtemp_sterilizer_capa_actions_r3347 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3347_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3347_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3347_high_risk_queue()
returns table(
  hospital_name text,
  machine_code text,
  sterilizer_type text,
  check_date date,
  audit_verdict text,
  biological_indicator_result text,
  chamber_leak_test text,
  eto_residual_aeration_ok text,
  plasma_cassette_stock text,
  exhaust_scrubber_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.machine_code, l.sterilizer_type, l.check_date,
    l.audit_verdict, l.biological_indicator_result, l.chamber_leak_test,
    l.eto_residual_aeration_ok, l.plasma_cassette_stock, l.exhaust_scrubber_ok, l.notes
  from public.lowtemp_sterilizer_r3347 l
  where l.audit_verdict in ('conditional_pass','fail','quarantined')
     or l.biological_indicator_result in ('fail','pending','not_run')
     or l.chamber_leak_test in ('fail','not_done')
     or l.eto_residual_aeration_ok = 'insufficient'
     or l.plasma_cassette_stock in ('low','empty')
     or l.exhaust_scrubber_ok = 'fault'
     or l.chemical_indicator_ok = false
     or l.temperature_pressure_profile_ok = false
     or l.load_release_documented = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3347_high_risk_queue() from public, anon;
grant execute on function public.founder_r3347_high_risk_queue() to authenticated;
