-- Round 3224: Engineer Safety-Incident, Near-Miss & PPE-Compliance Field Tracker
-- Field safety log — incident type × severity × PPE worn × lost-time days × site type × 24h reporting × CAPA

-- =============================================================================
-- TABLE 1: field_safety_r3224 — engineer field safety incident / near-miss log
-- =============================================================================
create table if not exists public.field_safety_r3224 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  incident_code text not null,
  incident_date date not null,
  reported_at timestamptz,
  incident_type text not null check (incident_type in (
    'electric_shock','sharps_injury','fall_from_height','radiation_exposure',
    'chemical_exposure','near_miss','manual_handling_strain','thermal_burn'
  )),
  severity text not null check (severity in (
    'near_miss_no_injury','first_aid_only','medical_treatment',
    'restricted_duty','lost_time_injury','critical_hospitalization'
  )),
  ppe_worn boolean not null default false,
  lost_time_days int not null default 0,
  site_type text not null check (site_type in (
    'hospital_ot','hospital_icu','radiology_suite','diagnostic_lab',
    'dialysis_unit','customer_warehouse','field_transit','workshop_bench'
  )),
  reported_within_24h boolean not null default false,
  incident_verdict text not null check (incident_verdict in (
    'open_investigation','capa_assigned','closed_no_action',
    'closed_with_capa','escalated_management','regulator_reported'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_safety_r3224 enable row level security;

create index if not exists idx_field_safety_r3224_org on public.field_safety_r3224(organization_id);
create index if not exists idx_field_safety_r3224_date on public.field_safety_r3224(incident_date);
create index if not exists idx_field_safety_r3224_verdict on public.field_safety_r3224(incident_verdict);

-- =============================================================================
-- TABLE 2: field_safety_capa_actions_r3224 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.field_safety_capa_actions_r3224 (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.field_safety_r3224(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ppe_noncompliance','unsafe_electrical_isolation','sharps_disposal_gap',
    'working_at_height_violation','radiation_badge_missing','chemical_handling_gap',
    'late_reporting','manual_handling_gap','tooling_defect','site_hazard_unmarked'
  )),
  root_cause text not null check (root_cause in (
    'ppe_not_issued','ppe_not_worn_by_choice','loto_procedure_skipped',
    'time_pressure_shortcut','training_not_completed','defective_insulated_tools',
    'no_site_induction','fatigue_long_shift','hazard_not_communicated','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'issue_ppe_kit','retrain_engineer','enforce_loto_checklist',
    'replace_insulated_toolkit','mandate_site_induction','revise_fatigue_rostering',
    'install_sharps_containers','issue_radiation_dosimeter','toolbox_talk_briefing','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'factories_act_reportable','esic_claim_filed','aerb_notifiable',
    'client_contract_breach','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_safety_capa_actions_r3224 enable row level security;

create index if not exists idx_field_safety_capa_r3224_incident on public.field_safety_capa_actions_r3224(incident_id);
create index if not exists idx_field_safety_capa_r3224_status on public.field_safety_capa_actions_r3224(capa_status);

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

  -- 13 incident rows
  insert into public.field_safety_r3224 (
    organization_id, hospital_name, engineer_name, incident_code,
    incident_date, reported_at, incident_type, severity,
    ppe_worn, lost_time_days, site_type, reported_within_24h,
    incident_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.code,
    q.idate::date, q.rat::timestamptz, q.itype, q.sev,
    q.ppe, q.ltd, q.site, q.r24,
    q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','R. Srinivas','SI-3224-001','2026-07-10','2026-07-10 11:20:00+05:30',
     'electric_shock','medical_treatment',false,2,'hospital_ot',true,'capa_assigned','Mains tingle while opening electrosurgical unit — isolation not verified before panel removal'),
    ('Apollo Hyderabad Jubilee Hills','R. Srinivas','SI-3224-002','2026-07-12','2026-07-13 18:05:00+05:30',
     'near_miss','near_miss_no_injury',true,0,'hospital_ot',false,'closed_with_capa','OT light counterweight slipped and nearly fell — reported next evening'),
    ('Fortis Bannerghatta Bengaluru','A. Kulkarni','SI-3224-003','2026-07-08','2026-07-08 09:40:00+05:30',
     'sharps_injury','first_aid_only',false,0,'diagnostic_lab',true,'closed_with_capa','Needlestick from uncapped sharp left in analyzer tray — nitrile gloves not worn'),
    ('Fortis Bannerghatta Bengaluru','A. Kulkarni','SI-3224-004','2026-07-09','2026-07-09 14:10:00+05:30',
     'fall_from_height','lost_time_injury',true,6,'customer_warehouse',true,'escalated_management','Ladder slipped while racking C-arm crates — six lost days, harness point absent'),
    ('Manipal Whitefield Bengaluru','P. Reddy','SI-3224-005','2026-07-05','2026-07-06 20:30:00+05:30',
     'radiation_exposure','medical_treatment',false,1,'radiology_suite',false,'regulator_reported','CT tube swap done with dosimeter left in the van — badge dose review triggered'),
    ('Manipal Whitefield Bengaluru','S. Iyer','SI-3224-006','2026-07-06','2026-07-06 10:15:00+05:30',
     'near_miss','near_miss_no_injury',true,0,'radiology_suite',true,'closed_no_action','Gantry rotation started during check — e-stop worked as designed'),
    ('AIIMS New Delhi Ansari Nagar','V. Sharma','SI-3224-007','2026-07-04','2026-07-04 08:55:00+05:30',
     'chemical_exposure','medical_treatment',false,3,'dialysis_unit',true,'capa_assigned','Peracetic acid splash during dialyzer disinfection — face shield not worn'),
    ('AIIMS New Delhi Ansari Nagar','V. Sharma','SI-3224-008','2026-07-11','2026-07-11 16:40:00+05:30',
     'manual_handling_strain','restricted_duty',true,0,'hospital_icu',true,'open_investigation','Lower-back strain lifting ventilator onto ICU shelf single-handed'),
    ('KIMS Secunderabad','M. Farooq','SI-3224-009','2026-07-07','2026-07-07 12:05:00+05:30',
     'electric_shock','lost_time_injury',false,4,'workshop_bench',true,'escalated_management','Defibrillator capacitor shock on bench — discharge stick not used'),
    ('Care Hospitals Banjara Hills','D. Nair','SI-3224-010','2026-07-03','2026-07-03 09:20:00+05:30',
     'near_miss','near_miss_no_injury',true,0,'hospital_icu',true,'closed_no_action','Oxygen cylinder trolley tipped in corridor — caught before impact'),
    ('Yashoda Somajiguda Hyderabad','K. Prasad','SI-3224-011','2026-07-02','2026-07-03 11:45:00+05:30',
     'thermal_burn','first_aid_only',false,0,'hospital_ot',false,'closed_with_capa','Forearm contact burn on hot autoclave jacket — heat gloves not worn, late report'),
    ('St John''s Bengaluru','T. George','SI-3224-012','2026-07-01','2026-07-01 07:50:00+05:30',
     'manual_handling_strain','first_aid_only',true,0,'field_transit',true,'closed_no_action','Shoulder tweak unloading syringe pumps from service van'),
    ('Rainbow Children''s Hyderabad','N. Verma','SI-3224-013','2026-06-30','2026-07-02 10:00:00+05:30',
     'radiation_exposure','near_miss_no_injury',false,0,'radiology_suite',false,'capa_assigned','Entered X-ray room during exposure — warning lamp defective, reported two days late')
  ) as q(hosp, eng, code, idate, rat, itype, sev, ppe, ltd, site, r24, verdict, nt);

  -- CAPA seed — attach to specific incidents by incident_code
  insert into public.field_safety_capa_actions_r3224 (
    incident_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('SI-3224-001','unsafe_electrical_isolation','loto_procedure_skipped','enforce_loto_checklist','2026-07-20',null,'in_progress','internal_only',8500.00,'LOTO kit and sign-off checklist now mandatory for ESU work'),
    ('SI-3224-003','sharps_disposal_gap','ppe_not_worn_by_choice','install_sharps_containers','2026-07-15','2026-07-12','closed','esic_claim_filed',6200.00,'Puncture-proof containers fitted at analyzer bays; gloves restocked'),
    ('SI-3224-004','working_at_height_violation','no_site_induction','mandate_site_induction','2026-07-25',null,'escalated','factories_act_reportable',18000.00,'Warehouse ladder policy and induction rollout under management review'),
    ('SI-3224-005','radiation_badge_missing','ppe_not_issued','issue_radiation_dosimeter','2026-07-18',null,'verification_pending','aerb_notifiable',9500.00,'Spare dosimeters stocked in every service van'),
    ('SI-3224-007','chemical_handling_gap','training_not_completed','retrain_engineer','2026-07-22',null,'open','client_contract_breach',4000.00,'Peracetic acid handling module assigned with face-shield issue'),
    ('SI-3224-009','unsafe_electrical_isolation','defective_insulated_tools','replace_insulated_toolkit','2026-07-10',null,'overdue','internal_only',22000.00,'1000V-rated insulated toolkit purchase pending approval'),
    ('SI-3224-013','late_reporting','hazard_not_communicated','toolbox_talk_briefing','2026-07-19','2026-07-16','closed','none',0.00,'Weekly toolbox talk on the report-within-24h rule delivered')
  ) as q(code, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.field_safety_r3224 e
    on e.organization_id = v_org_id and e.incident_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Incident verdict distribution
create or replace function public.founder_r3224_incident_verdict_rollup()
returns table(incident_verdict text, incidents bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_safety_r3224)
  select f.incident_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.field_safety_r3224 f
  group by f.incident_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_incident_verdict_rollup() from public, anon;
grant execute on function public.founder_r3224_incident_verdict_rollup() to authenticated;

-- 2) Engineer safety scorecard
create or replace function public.founder_r3224_engineer_scorecard()
returns table(
  engineer_name text,
  total_incidents bigint,
  near_misses bigint,
  lost_time_cases bigint,
  total_lost_days bigint,
  ppe_compliant bigint,
  on_time_reports bigint,
  ppe_compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.engineer_name,
    count(*)::bigint,
    count(*) filter (where f.incident_type = 'near_miss')::bigint,
    count(*) filter (where f.severity = 'lost_time_injury')::bigint,
    coalesce(sum(f.lost_time_days),0)::bigint,
    count(*) filter (where f.ppe_worn)::bigint,
    count(*) filter (where f.reported_within_24h)::bigint,
    round(100.0 * count(*) filter (where f.ppe_worn)::numeric / nullif(count(*),0), 1)
  from public.field_safety_r3224 f
  group by f.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3224_engineer_scorecard() to authenticated;

-- 3) Incident type × severity matrix
create or replace function public.founder_r3224_type_severity_matrix()
returns table(incident_type text, severity text, incidents bigint, ppe_gaps bigint, avg_lost_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.incident_type, f.severity, count(*)::bigint,
    count(*) filter (where not f.ppe_worn)::bigint,
    round(avg(f.lost_time_days)::numeric, 1)
  from public.field_safety_r3224 f
  group by f.incident_type, f.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_type_severity_matrix() from public, anon;
grant execute on function public.founder_r3224_type_severity_matrix() to authenticated;

-- 4) Daily incident trend
create or replace function public.founder_r3224_daily_trend()
returns table(incident_date date, incidents bigint, near_misses bigint, lost_time_cases bigint, ppe_gaps bigint, late_reports bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.incident_date,
    count(*)::bigint,
    count(*) filter (where f.incident_type = 'near_miss')::bigint,
    count(*) filter (where f.severity = 'lost_time_injury')::bigint,
    count(*) filter (where not f.ppe_worn)::bigint,
    count(*) filter (where not f.reported_within_24h)::bigint
  from public.field_safety_r3224 f
  group by f.incident_date
  order by f.incident_date desc;
end;
$$;

revoke execute on function public.founder_r3224_daily_trend() from public, anon;
grant execute on function public.founder_r3224_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3224_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.field_safety_capa_actions_r3224 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_capa_status_board() from public, anon;
grant execute on function public.founder_r3224_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3224_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_safety_capa_actions_r3224)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.field_safety_capa_actions_r3224 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3224_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3224_regulatory_impact_digest()
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
  from public.field_safety_capa_actions_r3224 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3224_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3224_regulatory_impact_digest() to authenticated;

-- 8) High-risk incident queue (open, severe, or PPE-gap cases)
create or replace function public.founder_r3224_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  incident_code text,
  incident_date date,
  incident_type text,
  severity text,
  ppe_worn text,
  lost_time_days int,
  incident_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.hospital_name, f.engineer_name, f.incident_code, f.incident_date,
    f.incident_type, f.severity,
    case when f.ppe_worn then 'yes' else 'no' end,
    f.lost_time_days, f.incident_verdict, f.notes
  from public.field_safety_r3224 f
  where f.incident_verdict in ('open_investigation','capa_assigned','escalated_management','regulator_reported')
     or f.severity in ('lost_time_injury','critical_hospitalization')
     or f.ppe_worn = false
  order by f.incident_date desc, f.hospital_name;
end;
$$;

revoke execute on function public.founder_r3224_high_risk_queue() from public, anon;
grant execute on function public.founder_r3224_high_risk_queue() to authenticated;
