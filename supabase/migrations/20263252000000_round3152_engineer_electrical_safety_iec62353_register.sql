-- Round 3152: Engineer Electrical-Safety Test (IEC 62353) PASS/FAIL Register
-- Biomedical electrical-safety log — device class × earth-bond × insulation × equipment/applied-part leakage × verdict × next-due × CAPA

-- =============================================================================
-- TABLE 1: electrical_safety_r3152 — individual IEC 62353 test records
-- =============================================================================
create table if not exists public.electrical_safety_r3152 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'infusion_pump','defibrillator','patient_monitor','ecg_machine','ventilator',
    'dialysis_machine','electrosurgical_unit','syringe_pump','ultrasound_scanner','infant_incubator'
  )),
  protection_class text not null check (protection_class in (
    'class_i','class_ii','internally_powered'
  )),
  applied_part_type text not null check (applied_part_type in (
    'type_b','type_bf','type_cf','no_applied_part'
  )),
  test_reason text not null check (test_reason in (
    'recurrent_periodic','after_repair','before_commissioning','after_incident','manufacturer_recall'
  )),
  measurement_method text not null check (measurement_method in (
    'direct','differential','alternative'
  )),
  test_date date not null,
  earth_bond_resistance_ohm numeric(6,3),
  insulation_resistance_mohm numeric(8,2),
  equipment_leakage_ua numeric(8,2),
  applied_part_leakage_ua numeric(8,2),
  test_verdict text not null check (test_verdict in (
    'pass','fail','conditional_pass','pass_with_observation','retest_required','quarantined'
  )),
  next_due_date date,
  engineer_name text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.electrical_safety_r3152 enable row level security;

create index if not exists idx_electrical_safety_r3152_org on public.electrical_safety_r3152(organization_id);
create index if not exists idx_electrical_safety_r3152_date on public.electrical_safety_r3152(test_date);
create index if not exists idx_electrical_safety_r3152_verdict on public.electrical_safety_r3152(test_verdict);

-- =============================================================================
-- TABLE 2: electrical_safety_capa_actions_r3152 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.electrical_safety_capa_actions_r3152 (
  id uuid primary key default gen_random_uuid(),
  test_log_id uuid not null references public.electrical_safety_r3152(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'earth_bond_high','insulation_low','equipment_leakage_high','applied_part_leakage_high',
    'enclosure_damage','mains_cord_damaged','fuse_rating_wrong','no_applied_part_test','overdue_retest','label_missing'
  )),
  root_cause text not null check (root_cause in (
    'corroded_earth_pin','damaged_mains_cable','degraded_insulation','moisture_ingress',
    'worn_strain_relief','component_ageing','manufacturing_defect','pending_investigation','improper_prior_repair','no_periodic_testing'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_mains_cord','repair_earth_connection','replace_power_supply','clean_and_dry_unit',
    'replace_strain_relief','recalibrate_tester','quarantine_device','condemn_device','none_required','schedule_amc_visit'
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

alter table public.electrical_safety_capa_actions_r3152 enable row level security;

create index if not exists idx_electrical_safety_capa_r3152_test on public.electrical_safety_capa_actions_r3152(test_log_id);
create index if not exists idx_electrical_safety_capa_r3152_status on public.electrical_safety_capa_actions_r3152(capa_status);

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

  -- 14 electrical-safety test rows
  insert into public.electrical_safety_r3152 (
    organization_id, hospital_name, department, device_asset_tag, device_model,
    device_type, protection_class, applied_part_type, test_reason, measurement_method,
    test_date, earth_bond_resistance_ohm, insulation_resistance_mohm, equipment_leakage_ua, applied_part_leakage_ua,
    test_verdict, next_due_date, engineer_name, notes
  )
  select v_org_id, q.hosp, q.dept, q.tag, q.model,
    q.dtype, q.pclass, q.apt, q.reason, q.method,
    q.td::date, q.ebr, q.ins, q.eql, q.apl,
    q.verdict, q.ndd::date, q.eng, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-1','ES-APL-1001','Baxter Sigma Spectrum','infusion_pump','class_i','type_cf','recurrent_periodic','direct','2026-07-05',0.120,120.00,180.50,22.00,'pass','2027-01-05','Ravi Kumar','Annual recurrent test — all parameters within IEC 62353 limits'),
    ('Apollo Hyderabad Jubilee Hills','CCU','ES-APL-1002','Philips HeartStart XL','defibrillator','class_i','type_bf','after_repair','direct','2026-07-05',0.150,95.00,240.00,35.00,'pass_with_observation','2027-01-05','Ravi Kumar','Post battery-board repair verification — leakage trending up, watch'),
    ('Fortis Bannerghatta Bengaluru','OT-2','ES-FRT-2001','Covidien ForceTriad','electrosurgical_unit','class_i','type_cf','recurrent_periodic','differential','2026-07-04',0.420,60.00,220.00,48.00,'fail',null,'Anil Sharma','Earth-bond 0.42 ohm exceeds 0.3 limit — protective earth defective'),
    ('Fortis Bannerghatta Bengaluru','ICU-2','ES-FRT-2002','Draeger Evita V300','ventilator','class_i','type_bf','recurrent_periodic','direct','2026-07-04',0.180,3.20,460.00,42.00,'conditional_pass','2026-10-04','Anil Sharma','Insulation 3.2 Mohm near lower bound — quarterly recheck imposed'),
    ('Manipal Whitefield Bengaluru','Dialysis','ES-MNP-3001','Fresenius 4008S','dialysis_machine','class_i','type_bf','recurrent_periodic','direct','2026-07-03',0.110,150.00,310.00,40.00,'pass','2027-01-03','Suresh Rao','Dialysis unit annual clearance — full pass'),
    ('Manipal Whitefield Bengaluru','NICU','ES-MNP-3002','GE Giraffe Incubator','infant_incubator','class_i','type_bf','after_incident','direct','2026-07-03',0.250,2.10,540.00,55.00,'fail',null,'Suresh Rao','Equipment leakage 540 uA exceeds 500 limit — incident follow-up'),
    ('AIIMS New Delhi Ansari Nagar','Cardiology','ES-AIM-4001','GE MAC 2000','ecg_machine','class_i','type_cf','recurrent_periodic','direct','2026-07-02',0.130,200.00,90.00,18.00,'pass','2027-07-02','Deepak Verma','ECG annual test — full pass, CF applied part within 10 uA margin'),
    ('AIIMS New Delhi Ansari Nagar','ICU-3','ES-AIM-4002','Philips IntelliVue MX800','patient_monitor','class_i','type_cf','before_commissioning','direct','2026-07-02',0.090,250.00,140.00,20.00,'pass','2027-07-02','Deepak Verma','New monitor commissioning baseline recorded'),
    ('KIMS Secunderabad','OT-1','ES-KIM-5001','Erbe VIO 300D','electrosurgical_unit','class_i','type_cf','recurrent_periodic','differential','2026-07-01',0.280,8.00,380.00,60.00,'retest_required','2026-07-15','Manoj Reddy','Applied-part leakage 60 uA above CF 50 limit — retest after service'),
    ('KIMS Secunderabad','Ward-5','ES-KIM-5002','BPL Relife 900','defibrillator','class_i','type_bf','recurrent_periodic','direct','2026-07-01',0.160,110.00,200.00,30.00,'pass','2027-01-01','Manoj Reddy','Routine periodic test — pass'),
    ('Care Hospitals Banjara Hills','ICU-1','ES-CAR-6001','Maquet Servo-i','ventilator','class_i','type_bf','recurrent_periodic','direct','2026-06-30',0.700,90.00,260.00,38.00,'quarantined',null,'Kiran Naidu','Earth continuity failed 0.7 ohm — device quarantined from service'),
    ('Yashoda Somajiguda Hyderabad','OT-3','ES-YSH-7001','Mindray BeneVision N22','patient_monitor','class_i','type_cf','recurrent_periodic','direct','2026-06-29',0.140,180.00,160.00,24.00,'pass','2027-06-29','Vamsi Krishna','OT monitor annual test — pass'),
    ('St John''s Bengaluru','Emergency','ES-STJ-8001','Nihon Kohden TEC-5600','defibrillator','class_ii','type_bf','recurrent_periodic','alternative','2026-06-28',null,300.00,150.00,28.00,'pass','2027-06-28','Joseph Thomas','Class II double-insulated — no earth bond applicable, leakage low'),
    ('Rainbow Children''s Hyderabad','NICU','ES-RBW-9001','Draeger Babylog VN500','ventilator','class_i','type_bf','after_repair','direct','2026-06-27',0.190,4.50,300.00,45.00,'pass_with_observation','2026-12-27','Naveen Chandra','Post-repair verification — insulation trending down, six-month recheck')
  ) as q(hosp, dept, tag, model, dtype, pclass, apt, reason, method, td, ebr, ins, eql, apl, verdict, ndd, eng, nt)
  where q.tag ~ '^ES-';

  -- CAPA seed — attach to specific tests by asset tag
  insert into public.electrical_safety_capa_actions_r3152 (
    test_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cs, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('ES-FRT-2001','earth_bond_high','corroded_earth_pin','repair_earth_connection','in_progress','nabh_finding','2026-07-12',null,8500.00,'Earth pin corroded at mains inlet — reterminated, awaiting retest'),
    ('ES-MNP-3002','equipment_leakage_high','damaged_mains_cable','replace_mains_cord','in_progress','patient_safety_alert','2026-07-10',null,3200.00,'Mains cord insulation cracked on NICU incubator — cord replaced'),
    ('ES-FRT-2002','insulation_low','moisture_ingress','clean_and_dry_unit','verification_pending','iso_13485_deviation','2026-07-11','2026-07-08',1500.00,'Internal moisture dried out, insulation recovered to 40 Mohm on recheck'),
    ('ES-KIM-5001','applied_part_leakage_high','degraded_insulation','replace_power_supply','escalated','cdsco_notifiable','2026-07-15',null,42000.00,'CF applied-part leakage above limit — PSU replacement ordered, escalated'),
    ('ES-CAR-6001','earth_bond_high','worn_strain_relief','replace_strain_relief','open','nabh_finding','2026-07-14',null,2800.00,'Strain relief worn at inlet grommet — device quarantined pending fix'),
    ('ES-RBW-9001','insulation_low','component_ageing','schedule_amc_visit','open','internal_only','2026-08-01',null,12000.00,'Insulation trending down on ageing ventilator — schedule AMC preventive service'),
    ('ES-APL-1002','overdue_retest','no_periodic_testing','none_required','closed','internal_only','2026-07-06','2026-07-05',0.00,'Prior test cycle had lapsed — device now back on six-month schedule')
  ) as q(tag_key, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.electrical_safety_r3152 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Test verdict distribution
create or replace function public.founder_r3152_verdict_rollup()
returns table(test_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrical_safety_r3152)
  select l.test_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.electrical_safety_r3152 l
  group by l.test_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_verdict_rollup() from public, anon;
grant execute on function public.founder_r3152_verdict_rollup() to authenticated;

-- 2) Hospital-level electrical-safety scorecard
create or replace function public.founder_r3152_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  passed bigint,
  failed bigint,
  quarantined bigint,
  retest_required bigint,
  avg_earth_bond_ohm numeric,
  avg_equipment_leakage_ua numeric,
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
    count(*) filter (where l.test_verdict in ('pass','pass_with_observation','conditional_pass'))::bigint,
    count(*) filter (where l.test_verdict = 'fail')::bigint,
    count(*) filter (where l.test_verdict = 'quarantined')::bigint,
    count(*) filter (where l.test_verdict = 'retest_required')::bigint,
    round(avg(l.earth_bond_resistance_ohm), 3),
    round(avg(l.equipment_leakage_ua), 1),
    round(100.0 * count(*) filter (where l.test_verdict in ('pass','pass_with_observation','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.electrical_safety_r3152 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3152_hospital_scorecard() to authenticated;

-- 3) Device-type × protection-class matrix
create or replace function public.founder_r3152_device_class_matrix()
returns table(device_type text, protection_class text, tests bigint, passed bigint, avg_equipment_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.protection_class, count(*)::bigint,
    count(*) filter (where l.test_verdict in ('pass','pass_with_observation','conditional_pass'))::bigint,
    round(avg(l.equipment_leakage_ua), 1)
  from public.electrical_safety_r3152 l
  group by l.device_type, l.protection_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_device_class_matrix() from public, anon;
grant execute on function public.founder_r3152_device_class_matrix() to authenticated;

-- 4) Daily test trend
create or replace function public.founder_r3152_test_daily_trend()
returns table(test_date date, tests bigint, passed bigint, failed bigint, quarantined bigint, retest_required bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.test_verdict in ('pass','pass_with_observation','conditional_pass'))::bigint,
    count(*) filter (where l.test_verdict = 'fail')::bigint,
    count(*) filter (where l.test_verdict = 'quarantined')::bigint,
    count(*) filter (where l.test_verdict = 'retest_required')::bigint
  from public.electrical_safety_r3152 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3152_test_daily_trend() from public, anon;
grant execute on function public.founder_r3152_test_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3152_capa_status_board()
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
  from public.electrical_safety_capa_actions_r3152 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_capa_status_board() from public, anon;
grant execute on function public.founder_r3152_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3152_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrical_safety_capa_actions_r3152)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.electrical_safety_capa_actions_r3152 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3152_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3152_regulatory_impact_digest()
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
  from public.electrical_safety_capa_actions_r3152 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3152_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3152_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority test queue (top individual concerns)
create or replace function public.founder_r3152_high_risk_tests()
returns table(
  hospital_name text,
  department text,
  device_asset_tag text,
  device_type text,
  test_date date,
  test_verdict text,
  earth_bond_resistance_ohm numeric,
  insulation_resistance_mohm numeric,
  equipment_leakage_ua numeric,
  applied_part_leakage_ua numeric,
  next_due_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.department, l.device_asset_tag, l.device_type, l.test_date,
    l.test_verdict, l.earth_bond_resistance_ohm, l.insulation_resistance_mohm,
    l.equipment_leakage_ua, l.applied_part_leakage_ua, l.next_due_date, l.notes
  from public.electrical_safety_r3152 l
  where l.test_verdict in ('fail','quarantined','retest_required','conditional_pass')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3152_high_risk_tests() from public, anon;
grant execute on function public.founder_r3152_high_risk_tests() to authenticated;
