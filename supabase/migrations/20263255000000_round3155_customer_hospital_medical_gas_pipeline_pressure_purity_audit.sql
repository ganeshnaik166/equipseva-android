-- Round 3155: Customer Hospital Medical-Gas Pipeline System (MGPS) Pressure & Purity Audit
-- MGPS outlet audit — gas type × clinical zone × line pressure × purity % × cross-connection × area-alarm × valve label × verdict + CAPA

-- =============================================================================
-- TABLE 1: medical_gas_r3155 — individual MGPS outlet audit checks
-- =============================================================================
create table if not exists public.medical_gas_r3155 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  outlet_location text not null,
  outlet_ref text not null,
  clinical_zone text not null check (clinical_zone in (
    'icu','ot','emergency','ward','nicu','picu',
    'labour_room','recovery','hdu','dialysis','endoscopy','ccu'
  )),
  gas_type text not null check (gas_type in (
    'oxygen','nitrous_oxide','medical_air_4bar','medical_air_7bar',
    'medical_vacuum','carbon_dioxide','entonox','nitrogen','agss'
  )),
  outlet_terminal_type text not null check (outlet_terminal_type in (
    'bed_head_panel','pendant','wall_mounted','ceiling_column','flowmeter','vacuum_regulator'
  )),
  line_pressure_bar numeric(5,2),
  purity_pct numeric(5,2),
  cross_connection_test text not null check (cross_connection_test in (
    'pass','fail','not_performed'
  )),
  area_alarm_test text not null check (area_alarm_test in (
    'pass','fail','delayed','not_performed'
  )),
  valve_label_status text not null check (valve_label_status in (
    'correct','mislabeled','missing','faded','not_checked'
  )),
  pressure_verdict text not null check (pressure_verdict in (
    'within_spec','below_spec','above_spec','fluctuating'
  )),
  purity_verdict text not null check (purity_verdict in (
    'pass','marginal','fail','not_tested'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  audit_verdict text not null check (audit_verdict in (
    'compliant','minor_nonconformity','major_nonconformity',
    'critical_failure','conditional_pass','recall_area'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_gas_r3155 enable row level security;

create index if not exists idx_medical_gas_r3155_org on public.medical_gas_r3155(organization_id);
create index if not exists idx_medical_gas_r3155_date on public.medical_gas_r3155(audit_date);
create index if not exists idx_medical_gas_r3155_verdict on public.medical_gas_r3155(audit_verdict);

-- =============================================================================
-- TABLE 2: medical_gas_capa_actions_r3155 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.medical_gas_capa_actions_r3155 (
  id uuid primary key default gen_random_uuid(),
  gas_audit_id uuid not null references public.medical_gas_r3155(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cross_connection','low_pressure','high_pressure','purity_fail',
    'alarm_failure','mislabeled_valve','contamination','leak_detected',
    'outlet_flow_low','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'valve_wrongly_piped','manifold_contamination','area_alarm_module_faulty',
    'line_regulator_drift','undersized_pipeline_peak_demand','missing_identification_tag',
    'pipeline_leak','cylinder_supply_impurity','sensor_calibration_drift',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'correct_pipe_routing','replace_alarm_module','purge_and_recertify_manifold',
    'recalibrate_line_regulator','upsize_riser_pipeline','replace_valve_identification_tag',
    'repair_pipeline_leak','replace_manifold_filter','schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_7396_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_gas_capa_actions_r3155 enable row level security;

create index if not exists idx_medical_gas_capa_r3155_audit on public.medical_gas_capa_actions_r3155(gas_audit_id);
create index if not exists idx_medical_gas_capa_r3155_status on public.medical_gas_capa_actions_r3155(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 MGPS outlet audit rows
  insert into public.medical_gas_r3155 (
    organization_id, hospital_name, outlet_location, outlet_ref, clinical_zone,
    gas_type, outlet_terminal_type, line_pressure_bar, purity_pct,
    cross_connection_test, area_alarm_test, valve_label_status,
    pressure_verdict, purity_verdict, audit_date, audited_at, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.loc, q.ref, q.zone,
    q.gas, q.term, q.press, q.pur,
    q.cct, q.aat, q.vls,
    q.pv, q.puv, q.ad::date, q.at::timestamptz, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-1 Bed Head 04','MGPS-APL-O2-ICU-04','icu',
     'oxygen','bed_head_panel',4.10,99.60,'pass','pass','correct','within_spec','pass',
     '2026-07-15','2026-07-15 09:10:00+05:30','compliant','O2 outlet nominal 4 bar, purity 99.6%'),
    ('Apollo Hyderabad Jubilee Hills','OT-3 Pendant','MGPS-APL-N2O-OT3','ot',
     'nitrous_oxide','pendant',4.05,98.20,'pass','pass','correct','within_spec','pass',
     '2026-07-15','2026-07-15 09:40:00+05:30','compliant','N2O pendant OT-3 within spec'),
    ('Fortis Bannerghatta Bengaluru','ICU-2 Bed Head 07','MGPS-FRT-VAC-ICU-07','icu',
     'medical_vacuum','vacuum_regulator',-0.55,null,'pass','fail','correct','below_spec','not_tested',
     '2026-07-14','2026-07-14 08:20:00+05:30','major_nonconformity','Vacuum only -0.55 bar; area alarm did not annunciate'),
    ('Fortis Bannerghatta Bengaluru','OT-1 Wall Manifold','MGPS-FRT-O2-OT1','ot',
     'oxygen','wall_mounted',4.15,92.40,'fail','pass','mislabeled','within_spec','fail',
     '2026-07-14','2026-07-14 09:00:00+05:30','critical_failure','Cross-connection: O2 outlet delivering air, purity 92.4%'),
    ('Manipal Whitefield Bengaluru','NICU Bed 03','MGPS-MNP-AIR4-NICU-03','nicu',
     'medical_air_4bar','bed_head_panel',4.00,99.10,'pass','pass','correct','within_spec','pass',
     '2026-07-13','2026-07-13 07:30:00+05:30','compliant','Medical air 4 bar NICU nominal'),
    ('Manipal Whitefield Bengaluru','OT-2 Ceiling Column','MGPS-MNP-VAC-OT2','ot',
     'medical_vacuum','ceiling_column',-0.72,null,'pass','pass','faded','within_spec','not_tested',
     '2026-07-13','2026-07-13 08:10:00+05:30','minor_nonconformity','Vacuum ok but valve label faded, reprint needed'),
    ('AIIMS New Delhi Ansari Nagar','Emergency Bay 05','MGPS-AIM-O2-EM-05','emergency',
     'oxygen','wall_mounted',3.60,99.40,'pass','pass','correct','below_spec','pass',
     '2026-07-12','2026-07-12 10:15:00+05:30','minor_nonconformity','O2 pressure sagging to 3.6 bar at peak demand'),
    ('AIIMS New Delhi Ansari Nagar','Labour Room Pendant','MGPS-AIM-ENT-LR','labour_room',
     'entonox','pendant',4.10,97.80,'pass','pass','correct','within_spec','pass',
     '2026-07-12','2026-07-12 10:50:00+05:30','compliant','Entonox 50/50 delivery within spec'),
    ('KIMS Secunderabad','CCU Bed 02','MGPS-KIM-O2-CCU-02','ccu',
     'oxygen','bed_head_panel',4.70,99.50,'pass','delayed','correct','above_spec','pass',
     '2026-07-11','2026-07-11 06:45:00+05:30','minor_nonconformity','Line pressure 4.7 bar above nominal; alarm annunciation delayed'),
    ('KIMS Secunderabad','Dialysis Wall Outlet 08','MGPS-KIM-AIR7-DIAL-08','dialysis',
     'medical_air_7bar','wall_mounted',7.05,99.00,'pass','pass','correct','within_spec','pass',
     '2026-07-11','2026-07-11 07:20:00+05:30','compliant','Surgical air 7 bar for tools nominal'),
    ('Care Hospitals Banjara Hills','HDU Bed 06','MGPS-CAR-CO2-HDU-06','hdu',
     'carbon_dioxide','wall_mounted',4.00,96.50,'pass','pass','missing','within_spec','marginal',
     '2026-07-10','2026-07-10 09:05:00+05:30','minor_nonconformity','CO2 purity marginal 96.5%; valve identification tag missing'),
    ('Yashoda Somajiguda Hyderabad','PICU Bed 01','MGPS-YSH-O2-PICU-01','picu',
     'oxygen','bed_head_panel',4.12,99.70,'pass','pass','correct','within_spec','pass',
     '2026-07-09','2026-07-09 08:30:00+05:30','compliant','PICU O2 outlet full compliance'),
    ('St John''s Bengaluru','Recovery Bay 03','MGPS-STJ-N2O-REC-03','recovery',
     'nitrous_oxide','flowmeter',4.08,91.20,'pass','pass','correct','within_spec','fail',
     '2026-07-08','2026-07-08 07:55:00+05:30','major_nonconformity','N2O purity 91.2% below 98% limit, manifold contamination suspected'),
    ('Rainbow Children''s Hyderabad','NICU Pendant 02','MGPS-RBW-AGSS-NICU-02','nicu',
     'agss','ceiling_column',-0.30,null,'not_performed','not_performed','not_checked','fluctuating','not_tested',
     '2026-07-07','2026-07-07 11:20:00+05:30','conditional_pass','AGSS scavenging flow fluctuating; full test deferred to next visit')
  ) as q(hosp, loc, ref, zone, gas, term, press, pur, cct, aat, vls, pv, puv, ad, at, av, nt);

  -- CAPA seed — attach to specific outlet audits by outlet_ref tag
  insert into public.medical_gas_capa_actions_r3155 (
    gas_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('MGPS-FRT-VAC-ICU-07','alarm_failure','area_alarm_module_faulty','replace_alarm_module',
     '2026-07-20',null,'in_progress','patient_safety_alert',35000.00,'ICU vacuum low-pressure alarm not annunciating, module replacement ordered'),
    ('MGPS-FRT-O2-OT1','cross_connection','valve_wrongly_piped','correct_pipe_routing',
     '2026-07-16',null,'escalated','cdsco_notifiable',120000.00,'CRITICAL: O2 outlet cross-connected to air, OT-1 shut, CDSCO notifiable'),
    ('MGPS-STJ-N2O-REC-03','purity_fail','manifold_contamination','purge_and_recertify_manifold',
     '2026-07-14','2026-07-13','closed','iso_7396_deviation',42000.00,'N2O manifold purged, recertified to 98.5%'),
    ('MGPS-KIM-O2-CCU-02','high_pressure','line_regulator_drift','recalibrate_line_regulator',
     '2026-07-18',null,'verification_pending','nabh_finding',8500.00,'Second-stage regulator drift to 4.7 bar, recalibrated, awaiting verification'),
    ('MGPS-AIM-O2-EM-05','low_pressure','undersized_pipeline_peak_demand','upsize_riser_pipeline',
     '2026-07-30',null,'open','internal_only',65000.00,'O2 sags to 3.6 bar at peak demand, riser upsizing planned'),
    ('MGPS-CAR-CO2-HDU-06','mislabeled_valve','missing_identification_tag','replace_valve_identification_tag',
     '2026-07-12',null,'overdue','nabh_finding',1500.00,'Valve ID tag missing since last audit, overdue by 3 days')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.medical_gas_r3155 e
    on e.organization_id = v_org_id and e.outlet_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3155_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_gas_r3155)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.medical_gas_r3155 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_verdict_rollup() from public, anon;
grant execute on function public.founder_r3155_verdict_rollup() to authenticated;

-- 2) Hospital-level MGPS compliance scorecard
create or replace function public.founder_r3155_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  major_nc bigint,
  critical bigint,
  cross_conn_fail bigint,
  purity_fail bigint,
  alarm_fail bigint,
  compliance_pct numeric
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
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'major_nonconformity')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    count(*) filter (where l.cross_connection_test = 'fail')::bigint,
    count(*) filter (where l.purity_verdict = 'fail')::bigint,
    count(*) filter (where l.area_alarm_test in ('fail','delayed'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.medical_gas_r3155 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3155_hospital_scorecard() to authenticated;

-- 3) Gas type × clinical zone breakdown
create or replace function public.founder_r3155_gas_zone_matrix()
returns table(gas_type text, clinical_zone text, audits bigint, compliant bigint, avg_pressure_bar numeric, avg_purity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gas_type, l.clinical_zone, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    round(avg(l.line_pressure_bar), 2),
    round(avg(l.purity_pct), 2)
  from public.medical_gas_r3155 l
  group by l.gas_type, l.clinical_zone
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_gas_zone_matrix() from public, anon;
grant execute on function public.founder_r3155_gas_zone_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3155_daily_trend()
returns table(audit_date date, audits bigint, compliant bigint, major_nc bigint, critical bigint, cross_conn_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'major_nonconformity')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    count(*) filter (where l.cross_connection_test = 'fail')::bigint
  from public.medical_gas_r3155 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3155_daily_trend() from public, anon;
grant execute on function public.founder_r3155_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3155_capa_status_board()
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
  from public.medical_gas_capa_actions_r3155 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_capa_status_board() from public, anon;
grant execute on function public.founder_r3155_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3155_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_gas_capa_actions_r3155)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.medical_gas_capa_actions_r3155 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3155_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3155_regulatory_impact_digest()
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
  from public.medical_gas_capa_actions_r3155 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3155_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3155_regulatory_impact_digest() to authenticated;

-- 8) High-risk outlet queue (top individual concerns)
create or replace function public.founder_r3155_high_risk_queue()
returns table(
  hospital_name text,
  outlet_location text,
  gas_type text,
  clinical_zone text,
  audit_date date,
  audit_verdict text,
  cross_connection_test text,
  purity_verdict text,
  area_alarm_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.outlet_location, l.gas_type, l.clinical_zone, l.audit_date,
    l.audit_verdict, l.cross_connection_test, l.purity_verdict, l.area_alarm_test, l.notes
  from public.medical_gas_r3155 l
  where l.audit_verdict in ('major_nonconformity','critical_failure','conditional_pass','recall_area')
     or l.cross_connection_test = 'fail'
     or l.purity_verdict = 'fail'
     or l.area_alarm_test in ('fail','delayed')
     or l.pressure_verdict in ('below_spec','above_spec','fluctuating')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3155_high_risk_queue() from public, anon;
grant execute on function public.founder_r3155_high_risk_queue() to authenticated;
