-- Round 3211: Customer Hospital ICU Bed, Air-Mattress & Patient-Weighing Function Audit
-- ICU bed QA log — articulation × cpr-release × side-rail lock × air-mattress cycling × weighing accuracy × battery backup × castor brake × CAPA

-- =============================================================================
-- TABLE 1: icu_bed_r3211 — individual ICU bed function audits
-- =============================================================================
create table if not exists public.icu_bed_r3211 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  icu_ward_code text not null,
  bed_asset_tag text not null,
  bed_model text not null,
  audit_date date not null,
  head_articulation_result text not null check (head_articulation_result in (
    'pass','fail','sluggish','motor_noise','not_tested'
  )),
  foot_articulation_result text not null check (foot_articulation_result in (
    'pass','fail','sluggish','motor_noise','not_tested'
  )),
  cpr_release_result text not null check (cpr_release_result in (
    'pass','fail','delayed_release','handle_stiff','not_tested'
  )),
  side_rail_lock_result text not null check (side_rail_lock_result in (
    'pass','fail','latch_worn','rattle_noise','not_tested'
  )),
  air_mattress_mode text not null check (air_mattress_mode in (
    'alternating','static','max_inflate','cpr_deflate','seat_inflate','not_fitted'
  )),
  air_mattress_pressure_cycles int,
  air_mattress_result text not null check (air_mattress_result in (
    'pass','fail','cell_leak','pump_noisy','hose_kinked','not_fitted'
  )),
  weighing_scale_fitted boolean not null default false,
  test_weight_kg numeric(6,2),
  measured_weight_kg numeric(6,2),
  weighing_accuracy_result text not null check (weighing_accuracy_result in (
    'within_tolerance','out_of_tolerance','drift_zero_error','load_cell_fault','not_fitted'
  )),
  battery_backup_minutes int,
  battery_backup_result text not null check (battery_backup_result in (
    'pass','fail','degraded','battery_swollen','not_tested'
  )),
  castor_brake_result text not null check (castor_brake_result in (
    'pass','fail','one_castor_weak','brake_pedal_stiff','not_tested'
  )),
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','conditional_use','restricted_use','out_of_service','pending_parts','scrap_recommended'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.icu_bed_r3211 enable row level security;

create index if not exists idx_icu_bed_r3211_org on public.icu_bed_r3211(organization_id);
create index if not exists idx_icu_bed_r3211_date on public.icu_bed_r3211(audit_date);
create index if not exists idx_icu_bed_r3211_verdict on public.icu_bed_r3211(audit_verdict);

-- =============================================================================
-- TABLE 2: icu_bed_capa_actions_r3211 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.icu_bed_capa_actions_r3211 (
  id uuid primary key default gen_random_uuid(),
  bed_audit_id uuid not null references public.icu_bed_r3211(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cpr_release_fail','side_rail_fail','articulation_fault','air_mattress_leak',
    'weighing_out_of_tolerance','battery_degraded','castor_brake_fail','frame_corrosion',
    'operator_misuse','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'actuator_motor_worn','hand_control_cable_damage','gas_spring_leak','rail_latch_mechanism_worn',
    'mattress_cell_puncture','pump_diaphragm_worn','load_cell_drift','battery_end_of_life',
    'castor_bearing_worn','cleaning_chemical_corrosion','operator_training_gap',
    'pending_investigation','spare_parts_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_actuator_motor','replace_hand_control','replace_gas_spring','replace_rail_latch_assembly',
    'patch_or_replace_mattress_cell','rebuild_air_pump','recalibrate_load_cells','replace_battery_pack',
    'replace_castor_set','apply_anticorrosion_treatment','retrain_nursing_staff',
    'schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.icu_bed_capa_actions_r3211 enable row level security;

create index if not exists idx_icu_bed_capa_r3211_audit on public.icu_bed_capa_actions_r3211(bed_audit_id);
create index if not exists idx_icu_bed_capa_r3211_status on public.icu_bed_capa_actions_r3211(capa_status);

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

  -- 14 bed audit rows
  insert into public.icu_bed_r3211 (
    organization_id, hospital_name, icu_ward_code, bed_asset_tag, bed_model,
    audit_date, head_articulation_result, foot_articulation_result, cpr_release_result,
    side_rail_lock_result, air_mattress_mode, air_mattress_pressure_cycles, air_mattress_result,
    weighing_scale_fitted, test_weight_kg, measured_weight_kg, weighing_accuracy_result,
    battery_backup_minutes, battery_backup_result, castor_brake_result,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model,
    q.ad::date, q.ha, q.fa, q.cpr,
    q.srl, q.amm, q.amc, q.amr,
    q.wsf, q.twk, q.mwk, q.war,
    q.bbm, q.bbr, q.cbr,
    q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-A','BED-APL-101','Hill-Rom Centrella','2026-07-10',
     'pass','pass','pass','pass','alternating',12,'pass',true,60.00,60.20,'within_tolerance',95,'pass','pass','fit_for_use','Full function audit clean — annual PM done same day'),
    ('Apollo Hyderabad Jubilee Hills','ICU-A','BED-APL-102','Hill-Rom Centrella','2026-07-10',
     'sluggish','pass','pass','pass','alternating',12,'pass',true,60.00,61.50,'out_of_tolerance',88,'pass','pass','conditional_use','Head actuator slow and scale reads 1.5 kg heavy'),
    ('Fortis Bannerghatta Bengaluru','MICU-1','BED-FRT-201','Stryker InTouch','2026-07-09',
     'pass','pass','delayed_release','pass','alternating',10,'pass',true,80.00,80.10,'within_tolerance',40,'degraded','pass','restricted_use','CPR release took 6 seconds — actuator suspect'),
    ('Fortis Bannerghatta Bengaluru','MICU-1','BED-FRT-202','Stryker InTouch','2026-07-09',
     'pass','pass','pass','latch_worn','static',8,'cell_leak',false,null,null,'not_fitted',92,'pass','one_castor_weak','restricted_use','Mattress cell 4 leaking; rail latch worn'),
    ('Manipal Whitefield Bengaluru','SICU-2','BED-MNP-301','Linet Multicare','2026-07-08',
     'pass','pass','pass','pass','max_inflate',15,'pass',true,100.00,100.05,'within_tolerance',110,'pass','pass','fit_for_use','Bariatric bed — all functions nominal'),
    ('Manipal Whitefield Bengaluru','SICU-2','BED-MNP-302','Linet Multicare','2026-07-08',
     'fail','motor_noise','pass','pass','alternating',9,'pump_noisy',true,100.00,97.80,'drift_zero_error',15,'fail','pass','out_of_service','Head section dead and battery holds 15 min only'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','BED-AIM-401','Midmark Assure','2026-07-07',
     'pass','pass','pass','pass','alternating',11,'pass',true,75.00,75.15,'within_tolerance',105,'pass','pass','fit_for_use','Routine quarterly audit'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','BED-AIM-402','Midmark Assure','2026-07-07',
     'pass','pass','handle_stiff','pass','cpr_deflate',14,'pass',false,null,null,'not_fitted',90,'pass','brake_pedal_stiff','conditional_use','CPR handle needs two-hand pull — lubrication ordered'),
    ('KIMS Secunderabad','CTICU-1','BED-KIM-501','Paramount A6','2026-07-06',
     'pass','pass','pass','fail','alternating',10,'pass',true,60.00,60.30,'within_tolerance',70,'degraded','pass','restricted_use','Left side rail will not lock upright — entrapment risk'),
    ('KIMS Secunderabad','CTICU-1','BED-KIM-502','Paramount A6','2026-07-06',
     'pass','pass','pass','pass','seat_inflate',13,'hose_kinked',true,60.00,59.95,'within_tolerance',85,'pass','pass','conditional_use','Seat-inflate hose kinked under frame — rerouted on site'),
    ('Care Hospitals Banjara Hills','HDU-1','BED-CAR-601','Hill-Rom 900 Accella','2026-07-05',
     'pass','pass','pass','pass','not_fitted',null,'not_fitted',true,40.00,40.02,'within_tolerance',100,'pass','pass','fit_for_use','HDU stepdown bed — foam mattress variant'),
    ('Yashoda Somajiguda Hyderabad','ICU-3','BED-YSH-701','Stryker SV2','2026-07-04',
     'pass','pass','pass','rattle_noise','alternating',12,'pass',true,90.00,94.60,'load_cell_fault',98,'pass','pass','restricted_use','Scale 4.6 kg off — load cell fault flagged'),
    ('St John''s Bengaluru','MICU-2','BED-STJ-801','Linet Eleganza 4','2026-07-03',
     'pass','pass','pass','pass','alternating',12,'pass',true,70.00,70.05,'within_tolerance',102,'pass','pass','fit_for_use','Weekly spot audit — clean'),
    ('Rainbow Children''s Hyderabad','PICU-1','BED-RBW-901','Novum Pedicraft','2026-07-02',
     'not_tested','not_tested','pass','pass','static',6,'pass',true,25.00,25.40,'out_of_tolerance',55,'battery_swollen','pass','pending_parts','Paediatric bed — battery swollen, replacement on order')
  ) as q(hosp, ward, tag, model, ad, ha, fa, cpr, srl, amm, amc, amr, wsf, twk, mwk, war, bbm, bbr, cbr, av, nt);

  -- CAPA seed — attach to specific bed audits
  insert into public.icu_bed_capa_actions_r3211 (
    bed_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('BED-FRT-201','cpr_release_fail','actuator_motor_worn','replace_actuator_motor','2026-07-14',null,'in_progress','patient_safety_alert',38500.00,'Stryker actuator on order — bed restricted till fitted'),
    ('BED-FRT-202','air_mattress_leak','mattress_cell_puncture','patch_or_replace_mattress_cell','2026-07-12','2026-07-11','closed','internal_only',6200.00,'Cell 4 replaced from ward spare kit'),
    ('BED-MNP-302','articulation_fault','actuator_motor_worn','replace_actuator_motor','2026-07-16',null,'escalated','nabh_finding',42000.00,'Head motor dead — escalated to OEM under AMC'),
    ('BED-KIM-501','side_rail_fail','rail_latch_mechanism_worn','replace_rail_latch_assembly','2026-07-10',null,'overdue','patient_safety_alert',9800.00,'Entrapment risk — latch kit shipment delayed'),
    ('BED-YSH-701','weighing_out_of_tolerance','load_cell_drift','recalibrate_load_cells','2026-07-11',null,'verification_pending','iso_13485_deviation',4500.00,'Recalibrated with certified weights — retest pending'),
    ('BED-RBW-901','battery_degraded','battery_end_of_life','replace_battery_pack','2026-07-20',null,'open','cdsco_notifiable',16000.00,'Swollen pack removed — bed on mains only till spare arrives'),
    ('BED-AIM-402','preventive_maintenance_due','spare_parts_backlog','schedule_amc_visit','2026-07-18',null,'open','none',3000.00,'CPR handle service and brake pedal lube in next AMC visit')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.icu_bed_r3211 e
    on e.organization_id = v_org_id and e.bed_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3211_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.icu_bed_r3211)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.icu_bed_r3211 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_verdict_rollup() from public, anon;
grant execute on function public.founder_r3211_verdict_rollup() to authenticated;

-- 2) Hospital-level bed fitness scorecard
create or replace function public.founder_r3211_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  restricted bigint,
  out_of_service bigint,
  cpr_faults bigint,
  rail_faults bigint,
  scale_faults bigint,
  fit_pct numeric
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
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict in ('conditional_use','restricted_use'))::bigint,
    count(*) filter (where l.audit_verdict in ('out_of_service','pending_parts','scrap_recommended'))::bigint,
    count(*) filter (where l.cpr_release_result in ('fail','delayed_release','handle_stiff'))::bigint,
    count(*) filter (where l.side_rail_lock_result in ('fail','latch_worn','rattle_noise'))::bigint,
    count(*) filter (where l.weighing_accuracy_result in ('out_of_tolerance','drift_zero_error','load_cell_fault'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.icu_bed_r3211 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3211_hospital_scorecard() to authenticated;

-- 3) Bed model × air-mattress mode matrix
create or replace function public.founder_r3211_bed_model_matrix()
returns table(bed_model text, air_mattress_mode text, audits bigint, fit_for_use bigint, avg_battery_backup_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bed_model, l.air_mattress_mode, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.battery_backup_minutes)::numeric, 0)
  from public.icu_bed_r3211 l
  group by l.bed_model, l.air_mattress_mode
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_bed_model_matrix() from public, anon;
grant execute on function public.founder_r3211_bed_model_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3211_daily_trend()
returns table(audit_date date, audits bigint, fit_for_use bigint, cpr_faults bigint, rail_faults bigint, battery_faults bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.cpr_release_result in ('fail','delayed_release','handle_stiff'))::bigint,
    count(*) filter (where l.side_rail_lock_result in ('fail','latch_worn','rattle_noise'))::bigint,
    count(*) filter (where l.battery_backup_result in ('fail','degraded','battery_swollen'))::bigint
  from public.icu_bed_r3211 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3211_daily_trend() from public, anon;
grant execute on function public.founder_r3211_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3211_capa_status_board()
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
  from public.icu_bed_capa_actions_r3211 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_capa_status_board() from public, anon;
grant execute on function public.founder_r3211_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3211_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.icu_bed_capa_actions_r3211)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.icu_bed_capa_actions_r3211 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3211_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3211_regulatory_impact_digest()
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
  from public.icu_bed_capa_actions_r3211 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3211_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3211_regulatory_impact_digest() to authenticated;

-- 8) High-risk beds queue (top individual concerns)
create or replace function public.founder_r3211_high_risk_beds()
returns table(
  hospital_name text,
  icu_ward_code text,
  bed_asset_tag text,
  bed_model text,
  audit_date date,
  audit_verdict text,
  cpr_release_result text,
  side_rail_lock_result text,
  battery_backup_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.icu_ward_code, l.bed_asset_tag, l.bed_model, l.audit_date,
    l.audit_verdict, l.cpr_release_result, l.side_rail_lock_result, l.battery_backup_result, l.notes
  from public.icu_bed_r3211 l
  where l.audit_verdict in ('conditional_use','restricted_use','out_of_service','pending_parts','scrap_recommended')
     or l.cpr_release_result in ('fail','delayed_release','handle_stiff')
     or l.side_rail_lock_result in ('fail','latch_worn','rattle_noise')
     or l.battery_backup_result in ('fail','battery_swollen')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3211_high_risk_beds() from public, anon;
grant execute on function public.founder_r3211_high_risk_beds() to authenticated;
