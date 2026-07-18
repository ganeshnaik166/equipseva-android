-- Round 3158: Customer Hospital OT Laminar-Air-Flow & HVAC Particle-Count / Pressure Audit
-- OT air quality log — ISO class target/measured × particle count 0.5um × air changes/hr × positive pressure Pa × temp/humidity × HEPA integrity × verdict × CAPA

-- =============================================================================
-- TABLE 1: ot_laf_hvac_r3158 — individual OT air-quality validation audits
-- =============================================================================
create table if not exists public.ot_laf_hvac_r3158 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  ot_type text not null check (ot_type in (
    'cardiac_surgery','orthopedic_joint','neurosurgery','general_surgery',
    'ophthalmology','transplant','cath_lab','obstetric'
  )),
  ahu_asset_tag text not null,
  audit_date date not null,
  audited_at timestamptz not null,
  iso_class_target text not null check (iso_class_target in (
    'iso_class_5','iso_class_6','iso_class_7','iso_class_8'
  )),
  iso_class_measured text not null check (iso_class_measured in (
    'iso_class_5','iso_class_6','iso_class_7','iso_class_8','worse_than_8'
  )),
  particle_count_05um_per_m3 int not null,
  particle_verdict text not null check (particle_verdict in (
    'within_limit','marginal','exceeded','grossly_exceeded'
  )),
  air_changes_per_hour numeric(5,2) not null,
  ach_verdict text not null check (ach_verdict in (
    'pass','marginal','fail','not_measured'
  )),
  positive_pressure_pa numeric(5,2) not null,
  pressure_verdict text not null check (pressure_verdict in (
    'positive_ok','low_positive','neutral','negative','fail'
  )),
  temperature_c numeric(4,2) not null,
  humidity_pct numeric(5,2) not null,
  hepa_integrity_result text not null check (hepa_integrity_result in (
    'pass','fail','minor_leak','patched','not_tested'
  )),
  test_condition text not null check (test_condition in (
    'at_rest','operational','as_built'
  )),
  audit_verdict text not null check (audit_verdict in (
    'compliant','minor_deviation','major_deviation','critical_fail','conditional_pass','remediation_pending'
  )),
  certified_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_laf_hvac_r3158 enable row level security;

create index if not exists idx_ot_laf_hvac_r3158_org on public.ot_laf_hvac_r3158(organization_id);
create index if not exists idx_ot_laf_hvac_r3158_date on public.ot_laf_hvac_r3158(audit_date);
create index if not exists idx_ot_laf_hvac_r3158_verdict on public.ot_laf_hvac_r3158(audit_verdict);

-- =============================================================================
-- TABLE 2: ot_laf_hvac_capa_actions_r3158 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_laf_hvac_capa_actions_r3158 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.ot_laf_hvac_r3158(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'particle_count_high','low_air_changes','pressure_reversal','hepa_leak',
    'temperature_deviation','humidity_deviation','ahu_filter_choked','duct_contamination',
    'damper_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'hepa_filter_saturated','prefilter_choked','ahu_blower_belt_worn','damper_actuator_fault',
    'duct_leakage','bms_sensor_drift','chiller_capacity_low','door_interlock_bypassed',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hepa_filter','replace_prefilter','rebalance_air_flow','repair_damper_actuator',
    'seal_duct_leak','recalibrate_bms_sensor','service_ahu_blower','reset_pressure_cascade',
    'none_required','schedule_amc_visit'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_14644_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_laf_hvac_capa_actions_r3158 enable row level security;

create index if not exists idx_ot_laf_hvac_capa_r3158_audit on public.ot_laf_hvac_capa_actions_r3158(audit_log_id);
create index if not exists idx_ot_laf_hvac_capa_r3158_status on public.ot_laf_hvac_capa_actions_r3158(capa_status);

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

  -- 13 OT air-quality audit rows
  insert into public.ot_laf_hvac_r3158 (
    organization_id, hospital_name, ot_room_code, ot_type, ahu_asset_tag,
    audit_date, audited_at, iso_class_target, iso_class_measured,
    particle_count_05um_per_m3, particle_verdict, air_changes_per_hour, ach_verdict,
    positive_pressure_pa, pressure_verdict, temperature_c, humidity_pct,
    hepa_integrity_result, test_condition, audit_verdict, certified_at, notes
  )
  select v_org_id, q.hosp, q.ot, q.otype, q.tag,
    q.ad::date, q.aat::timestamptz, q.tgt, q.meas,
    q.pc, q.pv, q.ach, q.achv,
    q.pp, q.prv, q.temp, q.hum,
    q.hepa, q.cond, q.av, q.cert::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-1','cardiac_surgery','AHU-APL-CT01','2026-07-15','2026-07-15 07:30:00+05:30','iso_class_5','iso_class_5',2800,'within_limit',22.0,'pass',12.5,'positive_ok',20.5,55.0,'pass','operational','compliant','2026-07-15 09:00:00+05:30','Annual validation — all parameters within ISO 14644 Class 5'),
    ('Apollo Hyderabad Jubilee Hills','OT-2','orthopedic_joint','AHU-APL-OR02','2026-07-15','2026-07-15 08:15:00+05:30','iso_class_5','iso_class_6',8200,'marginal',19.5,'marginal',9.0,'low_positive',21.0,58.0,'minor_leak','operational','minor_deviation',null,'HEPA minor leak at OT-2 supply grille — CAPA raised'),
    ('Fortis Bannerghatta Bengaluru','OT-1','neurosurgery','AHU-FRT-NS01','2026-07-14','2026-07-14 06:45:00+05:30','iso_class_5','iso_class_7',210000,'exceeded',15.0,'fail',3.0,'low_positive',22.5,62.0,'fail','operational','major_deviation',null,'HEPA integrity failed — particle count 20x limit'),
    ('Fortis Bannerghatta Bengaluru','OT-2','general_surgery','AHU-FRT-GS02','2026-07-14','2026-07-14 07:40:00+05:30','iso_class_7','worse_than_8',480000,'grossly_exceeded',9.0,'fail',-2.0,'negative',24.0,68.0,'fail','operational','critical_fail',null,'Negative pressure reversal — OT shut for remediation'),
    ('Manipal Whitefield Bengaluru','OT-3','transplant','AHU-MNP-TX03','2026-07-13','2026-07-13 07:10:00+05:30','iso_class_5','iso_class_5',3100,'within_limit',24.0,'pass',15.0,'positive_ok',20.0,52.0,'pass','operational','compliant','2026-07-13 09:30:00+05:30','Transplant OT certified for ISO Class 5'),
    ('Manipal Whitefield Bengaluru','OT-4','cardiac_surgery','AHU-MNP-CT04','2026-07-13','2026-07-13 08:20:00+05:30','iso_class_5','iso_class_6',9800,'marginal',20.0,'marginal',8.0,'low_positive',21.5,60.0,'patched','operational','conditional_pass',null,'HEPA patched pending replacement — conditional use'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','neurosurgery','AHU-AIM-NS05','2026-07-12','2026-07-12 06:30:00+05:30','iso_class_5','iso_class_5',2600,'within_limit',25.0,'pass',14.0,'positive_ok',20.5,54.0,'pass','operational','compliant','2026-07-12 08:45:00+05:30','Neuro OT full compliance'),
    ('AIIMS New Delhi Ansari Nagar','OT-6','ophthalmology','AHU-AIM-OP06','2026-07-12','2026-07-12 07:20:00+05:30','iso_class_7','iso_class_7',320000,'within_limit',21.0,'pass',11.0,'positive_ok',22.0,56.0,'pass','operational','compliant','2026-07-12 09:15:00+05:30','Ophthalmology OT within Class 7'),
    ('KIMS Secunderabad','OT-2','cath_lab','AHU-KIM-CL02','2026-07-11','2026-07-11 06:50:00+05:30','iso_class_7','worse_than_8',520000,'grossly_exceeded',12.0,'fail',1.0,'neutral',23.5,66.0,'fail','operational','critical_fail',null,'Cath lab pressure neutral, prefilter fully choked'),
    ('Care Hospitals Banjara Hills','OT-1','obstetric','AHU-CAR-OB01','2026-07-10','2026-07-10 07:05:00+05:30','iso_class_7','iso_class_8',410000,'marginal',18.0,'marginal',6.0,'low_positive',22.0,61.0,'minor_leak','operational','minor_deviation',null,'Low air changes — blower belt wear suspected'),
    ('Yashoda Somajiguda Hyderabad','OT-3','general_surgery','AHU-YSH-GS03','2026-07-09','2026-07-09 07:35:00+05:30','iso_class_7','iso_class_7',300000,'within_limit',20.5,'pass',10.0,'positive_ok',21.5,57.0,'pass','operational','compliant','2026-07-09 09:20:00+05:30','General OT compliant'),
    ('St John''s Bengaluru','OT-2','orthopedic_joint','AHU-STJ-OR02','2026-07-08','2026-07-08 06:40:00+05:30','iso_class_5','iso_class_6',8800,'marginal',19.0,'marginal',7.5,'low_positive',21.0,59.0,'patched','operational','remediation_pending',null,'Duct contamination found — remediation scheduled'),
    ('Rainbow Children''s Hyderabad','OT-1','general_surgery','AHU-RBW-GS01','2026-07-07','2026-07-07 07:00:00+05:30','iso_class_7','iso_class_8',390000,'marginal',16.5,'marginal',4.0,'low_positive',22.5,63.0,'not_tested','at_rest','remediation_pending',null,'PM overdue — HEPA integrity not tested this quarter')
  ) as q(hosp, ot, otype, tag, ad, aat, tgt, meas, pc, pv, ach, achv, pp, prv, temp, hum, hepa, cond, av, cert, nt);

  -- CAPA seed — attach to specific audits via ahu_asset_tag
  insert into public.ot_laf_hvac_capa_actions_r3158 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.st, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('AHU-FRT-NS01','hepa_leak','hepa_filter_saturated','replace_hepa_filter','in_progress','patient_safety_alert','2026-07-20',null,185000.00,'HEPA bank replacement scheduled, OT on backup'),
    ('AHU-FRT-GS02','pressure_reversal','damper_actuator_fault','repair_damper_actuator','escalated','nabh_finding','2026-07-18',null,95000.00,'Pressure cascade reversed — escalated to biomedical head'),
    ('AHU-KIM-CL02','particle_count_high','prefilter_choked','replace_prefilter','open','cdsco_notifiable','2026-07-22',null,42000.00,'Prefilter and HEPA both due — CDSCO notification filed'),
    ('AHU-APL-OR02','hepa_leak','hepa_filter_saturated','replace_hepa_filter','closed','iso_14644_deviation','2026-07-16','2026-07-15',175000.00,'HEPA replaced, re-validation passed Class 5'),
    ('AHU-CAR-OB01','low_air_changes','ahu_blower_belt_worn','service_ahu_blower','verification_pending','internal_only','2026-07-19',null,28000.00,'Belt replaced, awaiting re-measurement of ACH'),
    ('AHU-RBW-GS01','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','overdue','nabh_finding','2026-07-05',null,15000.00,'Quarterly HVAC PM overdue by 13 days'),
    ('AHU-STJ-OR02','duct_contamination','duct_leakage','seal_duct_leak','in_progress','iso_14644_deviation','2026-07-21',null,36000.00,'Supply duct microbial contamination — sealing in progress')
  ) as q(tag_key, fc, rc, ca, st, ri, tcd, acd, cost, nt)
  join public.ot_laf_hvac_r3158 e
    on e.organization_id = v_org_id and e.ahu_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3158_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_laf_hvac_r3158)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_laf_hvac_r3158 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_verdict_rollup() from public, anon;
grant execute on function public.founder_r3158_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3158_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  minor bigint,
  major bigint,
  critical bigint,
  hepa_fail bigint,
  pressure_fail bigint,
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
    count(*) filter (where l.audit_verdict in ('minor_deviation','conditional_pass'))::bigint,
    count(*) filter (where l.audit_verdict = 'major_deviation')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_fail')::bigint,
    count(*) filter (where l.hepa_integrity_result = 'fail')::bigint,
    count(*) filter (where l.pressure_verdict in ('negative','fail'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.ot_laf_hvac_r3158 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3158_hospital_scorecard() to authenticated;

-- 3) OT-type × ISO-class-target matrix
create or replace function public.founder_r3158_category_matrix()
returns table(ot_type text, iso_class_target text, audits bigint, compliant bigint, avg_particle numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ot_type, l.iso_class_target, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    round(avg(l.particle_count_05um_per_m3), 0)
  from public.ot_laf_hvac_r3158 l
  group by l.ot_type, l.iso_class_target
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_category_matrix() from public, anon;
grant execute on function public.founder_r3158_category_matrix() to authenticated;

-- 4) Daily air-quality trend
create or replace function public.founder_r3158_daily_trend()
returns table(audit_date date, audits bigint, compliant bigint, major_plus bigint, avg_ach numeric, avg_pressure numeric)
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
    count(*) filter (where l.audit_verdict in ('major_deviation','critical_fail'))::bigint,
    round(avg(l.air_changes_per_hour), 2),
    round(avg(l.positive_pressure_pa), 2)
  from public.ot_laf_hvac_r3158 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3158_daily_trend() from public, anon;
grant execute on function public.founder_r3158_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3158_capa_status_board()
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
  from public.ot_laf_hvac_capa_actions_r3158 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_capa_status_board() from public, anon;
grant execute on function public.founder_r3158_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3158_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_laf_hvac_capa_actions_r3158)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_laf_hvac_capa_actions_r3158 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3158_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3158_regulatory_impact_digest()
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
  from public.ot_laf_hvac_capa_actions_r3158 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3158_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3158_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (top individual concerns)
create or replace function public.founder_r3158_high_risk_queue()
returns table(
  hospital_name text,
  ot_room_code text,
  ahu_asset_tag text,
  audit_date date,
  audit_verdict text,
  iso_class_measured text,
  particle_verdict text,
  pressure_verdict text,
  hepa_integrity_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.ahu_asset_tag, l.audit_date,
    l.audit_verdict, l.iso_class_measured, l.particle_verdict, l.pressure_verdict, l.hepa_integrity_result, l.notes
  from public.ot_laf_hvac_r3158 l
  where l.audit_verdict in ('minor_deviation','major_deviation','critical_fail','conditional_pass','remediation_pending')
     or l.particle_verdict in ('exceeded','grossly_exceeded')
     or l.pressure_verdict in ('negative','fail')
     or l.hepa_integrity_result = 'fail'
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3158_high_risk_queue() from public, anon;
grant execute on function public.founder_r3158_high_risk_queue() to authenticated;
