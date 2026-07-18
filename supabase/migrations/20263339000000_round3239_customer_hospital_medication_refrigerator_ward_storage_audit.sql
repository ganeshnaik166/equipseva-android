-- Round 3239: Customer Hospital Medication-Refrigerator & Ward-Drug-Storage Temperature Audit
-- Med storage QA — location type × temp-range compliance × data logger × excursions 30d × stock expiry × lock/access control × high-alert segregation × CAPA

-- =============================================================================
-- TABLE 1: med_storage_r3239 — medication storage audit log
-- =============================================================================
create table if not exists public.med_storage_r3239 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_name text not null,
  storage_unit_tag text not null,
  storage_location_type text not null check (storage_location_type in (
    'ward_medication_fridge','insulin_fridge','narcotics_safe',
    'emergency_crash_cart_box','vaccine_fridge','ward_drug_cupboard'
  )),
  audit_date date not null,
  min_temp_c numeric(5,2),
  max_temp_c numeric(5,2),
  target_range text not null check (target_range in (
    'range_2_to_8_c','range_15_to_25_c','range_below_25_c','frozen_minus_15_to_minus_25_c'
  )),
  temp_range_compliance text not null check (temp_range_compliance in (
    'within_range','minor_excursion','major_excursion','no_data'
  )),
  data_logger_status text not null check (data_logger_status in (
    'calibrated_logger_present','logger_present_uncalibrated','manual_chart_only','no_monitoring'
  )),
  excursions_30d int not null default 0,
  longest_excursion_minutes int,
  nearest_stock_expiry_days int,
  lock_access_control text not null check (lock_access_control in (
    'digital_lock_audit_trail','key_lock_controlled','key_lock_shared','unlocked'
  )),
  high_alert_meds_segregated boolean not null default false,
  audit_verdict text not null check (audit_verdict in (
    'compliant','observations_minor','non_compliant_major','critical_stop_use','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.med_storage_r3239 enable row level security;

create index if not exists idx_med_storage_r3239_org on public.med_storage_r3239(organization_id);
create index if not exists idx_med_storage_r3239_date on public.med_storage_r3239(audit_date);
create index if not exists idx_med_storage_r3239_verdict on public.med_storage_r3239(audit_verdict);

-- =============================================================================
-- TABLE 2: med_storage_capa_actions_r3239 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.med_storage_capa_actions_r3239 (
  id uuid primary key default gen_random_uuid(),
  storage_audit_id uuid not null references public.med_storage_r3239(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_excursion','logger_missing_or_uncalibrated','expired_stock_found',
    'near_expiry_stock','access_control_gap','high_alert_mixup_risk','documentation_gap','power_backup_gap'
  )),
  root_cause text not null check (root_cause in (
    'compressor_aging','door_seal_worn','frequent_door_opening','no_calibration_contract',
    'stock_rotation_lapse','staffing_gap','lock_hardware_broken','ups_not_connected',
    'pending_investigation','training_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_fridge_compressor','replace_door_gasket','install_calibrated_logger',
    'schedule_logger_calibration','remove_expired_stock','implement_fefo_rotation',
    'install_digital_lock','connect_ups_backup','retrain_ward_staff',
    'segregate_high_alert_meds','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','state_drug_authority_notifiable','narcotics_act_compliance',
    'internal_only','patient_safety_alert','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.med_storage_capa_actions_r3239 enable row level security;

create index if not exists idx_med_storage_capa_r3239_audit on public.med_storage_capa_actions_r3239(storage_audit_id);
create index if not exists idx_med_storage_capa_r3239_status on public.med_storage_capa_actions_r3239(capa_status);

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

  -- 14 storage audit rows
  insert into public.med_storage_r3239 (
    organization_id, hospital_name, ward_name, storage_unit_tag, storage_location_type,
    audit_date, min_temp_c, max_temp_c, target_range, temp_range_compliance,
    data_logger_status, excursions_30d, longest_excursion_minutes, nearest_stock_expiry_days,
    lock_access_control, high_alert_meds_segregated, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.loc,
    q.ad::date, q.mn, q.mx, q.tr, q.tc,
    q.dl, q.ex, q.lem, q.ned,
    q.lac, q.seg, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU Ward A','FR-APL-101','ward_medication_fridge',
     '2026-07-02',3.10,6.80,'range_2_to_8_c','within_range',
     'calibrated_logger_present',0,null,92,
     'key_lock_controlled',true,'compliant','Logger calibration valid till Dec 2026'),
    ('Apollo Hyderabad Jubilee Hills','Endocrine Ward','FR-APL-102','insulin_fridge',
     '2026-07-02',2.20,8.90,'range_2_to_8_c','minor_excursion',
     'calibrated_logger_present',2,35,60,
     'key_lock_controlled',true,'observations_minor','Two brief door-open excursions on night shift'),
    ('Fortis Bannerghatta Bengaluru','General Ward 3','FR-FRT-201','ward_medication_fridge',
     '2026-07-01',4.00,11.50,'range_2_to_8_c','major_excursion',
     'logger_present_uncalibrated',6,240,45,
     'key_lock_shared',false,'non_compliant_major','Compressor struggling — 11.5C peak held for 4 hours'),
    ('Fortis Bannerghatta Bengaluru','OT Complex','NS-FRT-202','narcotics_safe',
     '2026-07-01',null,null,'range_below_25_c','within_range',
     'manual_chart_only',0,null,180,
     'digital_lock_audit_trail',true,'compliant','Narcotics register matches physical stock count'),
    ('Manipal Whitefield Bengaluru','Pediatric Ward','FR-MNP-301','vaccine_fridge',
     '2026-06-30',1.20,7.90,'range_2_to_8_c','minor_excursion',
     'calibrated_logger_present',1,20,75,
     'key_lock_controlled',true,'observations_minor','Brief 1.2C dip after defrost cycle'),
    ('Manipal Whitefield Bengaluru','Emergency','EB-MNP-302','emergency_crash_cart_box',
     '2026-06-30',24.00,31.00,'range_below_25_c','major_excursion',
     'no_monitoring',8,480,12,
     'unlocked',false,'critical_stop_use','Crash cart box near window — adrenaline stock 12 days to expiry'),
    ('AIIMS New Delhi Ansari Nagar','Cardiology Ward','FR-AIM-401','ward_medication_fridge',
     '2026-06-29',2.80,7.20,'range_2_to_8_c','within_range',
     'calibrated_logger_present',0,null,120,
     'key_lock_controlled',true,'compliant','Model NABH-ready setup with alarm escalation'),
    ('AIIMS New Delhi Ansari Nagar','Oncology Day Care','FR-AIM-402','insulin_fridge',
     '2026-06-29',3.00,9.60,'range_2_to_8_c','minor_excursion',
     'logger_present_uncalibrated',3,55,30,
     'key_lock_shared',false,'observations_minor','Logger calibration certificate expired in May'),
    ('KIMS Secunderabad','Surgical Ward 2','FR-KIM-501','ward_medication_fridge',
     '2026-06-28',5.10,13.20,'range_2_to_8_c','major_excursion',
     'manual_chart_only',9,360,20,
     'key_lock_shared',false,'non_compliant_major','Manual chart gaps on weekends — 9 excursions in 30 days'),
    ('Care Hospitals Banjara Hills','ICU','NS-CAR-601','narcotics_safe',
     '2026-06-28',null,null,'range_below_25_c','within_range',
     'manual_chart_only',0,null,150,
     'key_lock_controlled',true,'compliant','Dual-key custody protocol followed'),
    ('Yashoda Somajiguda Hyderabad','Medicine Ward 4','FR-YSH-701','ward_medication_fridge',
     '2026-06-27',2.50,8.40,'range_2_to_8_c','minor_excursion',
     'calibrated_logger_present',2,25,90,
     'digital_lock_audit_trail',true,'observations_minor','Short excursions during morning drug rounds'),
    ('St John''s Bengaluru','NICU','FR-STJ-801','vaccine_fridge',
     '2026-06-27',2.90,6.50,'range_2_to_8_c','within_range',
     'calibrated_logger_present',0,null,200,
     'digital_lock_audit_trail',true,'compliant','NICU fridge on UPS with SMS temperature alerts'),
    ('Rainbow Children''s Hyderabad','PICU','FR-RBW-901','insulin_fridge',
     '2026-06-26',0.40,7.00,'range_2_to_8_c','major_excursion',
     'calibrated_logger_present',4,90,40,
     'key_lock_controlled',false,'pending_review','Freezing risk — 0.4C low reading, insulin potency review pending'),
    ('Rainbow Children''s Hyderabad','General Pediatric Ward','CB-RBW-902','ward_drug_cupboard',
     '2026-06-26',null,null,'range_15_to_25_c','no_data',
     'no_monitoring',0,null,25,
     'unlocked',false,'non_compliant_major','Cupboard unlocked and no ambient temperature monitoring')
  ) as q(hosp, ward, tag, loc, ad, mn, mx, tr, tc, dl, ex, lem, ned, lac, seg, av, nt);

  -- CAPA seed — attach to specific storage units
  insert into public.med_storage_capa_actions_r3239 (
    storage_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('FR-FRT-201','temperature_excursion','compressor_aging','replace_fridge_compressor',
     '2026-07-08',null,'in_progress','nabh_finding',18500.00,'Compressor quote approved, part in transit'),
    ('EB-MNP-302','near_expiry_stock','stock_rotation_lapse','remove_expired_stock',
     '2026-07-03','2026-07-02','closed','patient_safety_alert',0.00,'Adrenaline replaced; FEFO chart added to crash cart'),
    ('EB-MNP-302','power_backup_gap','ups_not_connected','connect_ups_backup',
     '2026-07-10',null,'open','patient_safety_alert',9500.00,'Relocate box away from window; add ambient logger'),
    ('FR-AIM-402','logger_missing_or_uncalibrated','no_calibration_contract','schedule_logger_calibration',
     '2026-07-06',null,'verification_pending','internal_only',2800.00,'Calibration vendor visit booked for next week'),
    ('FR-KIM-501','documentation_gap','staffing_gap','install_calibrated_logger',
     '2026-07-05',null,'escalated','nabh_finding',6200.00,'Weekend chart gaps — auto logger to replace manual chart'),
    ('CB-RBW-902','access_control_gap','lock_hardware_broken','install_digital_lock',
     '2026-06-24',null,'overdue','state_drug_authority_notifiable',4500.00,'Lock PO raised, closure overdue by 2 days'),
    ('FR-RBW-901','high_alert_mixup_risk','training_gap','segregate_high_alert_meds',
     '2026-07-09',null,'open','patient_safety_alert',0.00,'Insulin stored beside heparin — segregation bins ordered')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.med_storage_r3239 e
    on e.organization_id = v_org_id and e.storage_unit_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3239_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.med_storage_r3239)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.med_storage_r3239 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_verdict_rollup() from public, anon;
grant execute on function public.founder_r3239_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3239_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  minor_observations bigint,
  major_non_compliant bigint,
  critical_stop bigint,
  avg_excursions_30d numeric,
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
    count(*) filter (where l.audit_verdict = 'observations_minor')::bigint,
    count(*) filter (where l.audit_verdict = 'non_compliant_major')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_stop_use')::bigint,
    round(avg(l.excursions_30d)::numeric, 1),
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.med_storage_r3239 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3239_hospital_scorecard() to authenticated;

-- 3) Location type × temp compliance matrix
create or replace function public.founder_r3239_location_compliance_matrix()
returns table(storage_location_type text, temp_range_compliance text, audits bigint, avg_excursions_30d numeric, min_stock_expiry_days int)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.storage_location_type, l.temp_range_compliance, count(*)::bigint,
    round(avg(l.excursions_30d)::numeric, 1),
    min(l.nearest_stock_expiry_days)::int
  from public.med_storage_r3239 l
  group by l.storage_location_type, l.temp_range_compliance
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_location_compliance_matrix() from public, anon;
grant execute on function public.founder_r3239_location_compliance_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3239_daily_trend()
returns table(audit_date date, audits bigint, within_range bigint, minor_excursions bigint, major_excursions bigint, no_data bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.temp_range_compliance = 'within_range')::bigint,
    count(*) filter (where l.temp_range_compliance = 'minor_excursion')::bigint,
    count(*) filter (where l.temp_range_compliance = 'major_excursion')::bigint,
    count(*) filter (where l.temp_range_compliance = 'no_data')::bigint
  from public.med_storage_r3239 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3239_daily_trend() from public, anon;
grant execute on function public.founder_r3239_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3239_capa_status_board()
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
  from public.med_storage_capa_actions_r3239 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_capa_status_board() from public, anon;
grant execute on function public.founder_r3239_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3239_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.med_storage_capa_actions_r3239)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.med_storage_capa_actions_r3239 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3239_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3239_regulatory_impact_digest()
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
  from public.med_storage_capa_actions_r3239 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3239_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3239_regulatory_impact_digest() to authenticated;

-- 8) High-risk storage units queue
create or replace function public.founder_r3239_high_risk_storage_queue()
returns table(
  hospital_name text,
  ward_name text,
  storage_unit_tag text,
  storage_location_type text,
  audit_date date,
  audit_verdict text,
  temp_range_compliance text,
  excursions_30d int,
  nearest_stock_expiry_days int,
  lock_access_control text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_name, l.storage_unit_tag, l.storage_location_type,
    l.audit_date, l.audit_verdict, l.temp_range_compliance,
    l.excursions_30d, l.nearest_stock_expiry_days, l.lock_access_control, l.notes
  from public.med_storage_r3239 l
  where l.audit_verdict in ('non_compliant_major','critical_stop_use','pending_review')
     or l.temp_range_compliance = 'major_excursion'
     or l.lock_access_control = 'unlocked'
     or coalesce(l.nearest_stock_expiry_days, 9999) <= 30
     or l.high_alert_meds_segregated = false
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3239_high_risk_storage_queue() from public, anon;
grant execute on function public.founder_r3239_high_risk_storage_queue() to authenticated;
