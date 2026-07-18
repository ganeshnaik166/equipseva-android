-- Round 3222: Customer Hospital Surgical-Drill, Saw & Powered-Instrument Torque-Safety Audit
-- Powered instrument QA — instrument type × rpm accuracy × torque output × battery/hose × chuck runout × sterilization cycles × lubrication × CAPA

-- =============================================================================
-- TABLE 1: surgical_drill_r3222 — powered-instrument torque-safety audit log
-- =============================================================================
create table if not exists public.surgical_drill_r3222 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  instrument_asset_tag text not null,
  instrument_model text not null,
  instrument_type text not null check (instrument_type in (
    'ortho_drill','sagittal_saw','oscillating_saw','reciprocating_saw',
    'acetabular_reamer','wire_driver','dermatome','craniotome'
  )),
  power_source text not null check (power_source in (
    'battery_liion','battery_nimh','pneumatic_hose','electric_mains'
  )),
  test_date date not null,
  tested_at timestamptz,
  rated_rpm int not null,
  measured_rpm int,
  rpm_deviation_pct numeric(5,2),
  rated_torque_nm numeric(6,2) not null,
  measured_torque_nm numeric(6,2),
  torque_verdict text check (torque_verdict in ('pass','fail','borderline','not_run')),
  battery_hose_condition text not null check (battery_hose_condition in (
    'good','degraded','swollen_battery','cracked_hose','leaking_hose','replace_now','not_applicable'
  )),
  chuck_runout_mm numeric(4,2),
  chuck_runout_verdict text check (chuck_runout_verdict in ('pass','fail','borderline','not_run')),
  sterilization_cycle_count int not null default 0,
  lubrication_done boolean not null default false,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','restricted_use','quarantined','withdrawn','pending_review','sent_for_repair'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.surgical_drill_r3222 enable row level security;

create index if not exists idx_surgical_drill_r3222_org on public.surgical_drill_r3222(organization_id);
create index if not exists idx_surgical_drill_r3222_date on public.surgical_drill_r3222(test_date);
create index if not exists idx_surgical_drill_r3222_verdict on public.surgical_drill_r3222(audit_verdict);

-- =============================================================================
-- TABLE 2: surgical_drill_capa_actions_r3222 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.surgical_drill_capa_actions_r3222 (
  id uuid primary key default gen_random_uuid(),
  drill_log_id uuid not null references public.surgical_drill_r3222(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'rpm_deviation','torque_low','torque_over','chuck_runout_excess','battery_swollen',
    'hose_leak','overheating','noise_vibration','lubrication_missed','sterilization_cycle_limit'
  )),
  root_cause text not null check (root_cause in (
    'motor_brush_worn','gearbox_wear','battery_cell_aging','hose_seal_perished',
    'chuck_bearing_worn','calibration_overdue','lubricant_not_per_ifu',
    'autoclave_overexposure','operator_handling_damage','pending_investigation','oem_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_motor_brushes','overhaul_gearbox','replace_battery_pack','replace_hose_assembly',
    'replace_chuck_bearing','recalibrate_torque_tester','retrain_technician',
    'withdraw_instrument','send_to_oem_service','schedule_amc_visit','none_required'
  )),
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

alter table public.surgical_drill_capa_actions_r3222 enable row level security;

create index if not exists idx_surgical_drill_capa_r3222_log on public.surgical_drill_capa_actions_r3222(drill_log_id);
create index if not exists idx_surgical_drill_capa_r3222_status on public.surgical_drill_capa_actions_r3222(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 13 audit log rows
  insert into public.surgical_drill_r3222 (
    organization_id, hospital_name, ot_room_code, instrument_asset_tag, instrument_model,
    instrument_type, power_source, test_date, tested_at,
    rated_rpm, measured_rpm, rpm_deviation_pct, rated_torque_nm, measured_torque_nm, torque_verdict,
    battery_hose_condition, chuck_runout_mm, chuck_runout_verdict,
    sterilization_cycle_count, lubrication_done, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.itype, q.pwr, q.td::date, q.ts::timestamptz,
    q.rr, q.mr, q.dev, q.rt, q.mt, q.tv,
    q.bhc, q.cr, q.crv,
    q.scc, q.lub, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-2','PD-APL-101','Stryker System 8 Drill','ortho_drill','battery_liion','2026-07-02','2026-07-02 08:30:00+05:30',
     1400,1385,1.07,6.00,5.85,'pass','good',0.05,'pass',148,true,'fit_for_use','Annual torque bench test — all parameters within IFU limits'),
    ('Apollo Hyderabad Jubilee Hills','OT-2','PD-APL-102','Stryker System 8 Sagittal','sagittal_saw','battery_liion','2026-07-02','2026-07-02 09:10:00+05:30',
     12000,11100,7.50,1.80,1.55,'borderline','degraded',0.09,'pass',212,true,'restricted_use','RPM 7.5% low — battery pack aging, restricted to non-precision cuts'),
    ('Fortis Bannerghatta Bengaluru','OT-1','PD-FRT-201','Synthes Colibri II','ortho_drill','battery_liion','2026-07-01','2026-07-01 07:45:00+05:30',
     1200,1190,0.83,5.50,5.40,'pass','swollen_battery',0.04,'pass',176,true,'quarantined','Battery pack swollen — instrument quarantined until pack replaced'),
    ('Fortis Bannerghatta Bengaluru','OT-3','PD-FRT-202','Hall MicroChoice Saw','oscillating_saw','pneumatic_hose','2026-07-01','2026-07-01 08:20:00+05:30',
     15000,13200,12.00,2.10,1.60,'fail','leaking_hose',0.12,'borderline',305,false,'sent_for_repair','Hose leak drops line pressure — torque fail, lubrication step also missed'),
    ('Manipal Whitefield Bengaluru','OT-2','PD-MNP-301','Stryker RemB Reamer','acetabular_reamer','battery_liion','2026-06-30','2026-06-30 10:00:00+05:30',
     280,274,2.14,22.00,21.40,'pass','good',0.07,'pass',96,true,'fit_for_use','High-torque reamer within spec at 22 Nm rating'),
    ('Manipal Whitefield Bengaluru','OT-4','PD-MNP-302','Zimmer Universal Wire Driver','wire_driver','battery_nimh','2026-06-30','2026-06-30 11:15:00+05:30',
     900,815,9.44,3.20,2.70,'fail','degraded',0.18,'fail',388,true,'withdrawn','Chuck runout 0.18 mm and torque fail — withdrawn from service'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','PD-AIM-401','Aesculap Acculan 4','ortho_drill','battery_liion','2026-06-30','2026-06-30 06:40:00+05:30',
     1350,1342,0.59,6.50,6.45,'pass','good',0.03,'pass',64,true,'fit_for_use','New instrument — first annual audit clean'),
    ('AIIMS New Delhi Ansari Nagar','OT-7','PD-AIM-402','Zimmer Air Dermatome','dermatome','pneumatic_hose','2026-06-29','2026-06-29 07:30:00+05:30',
     4500,4380,2.67,1.20,1.14,'pass','cracked_hose',null,'not_run',154,true,'restricted_use','Hose jacket cracked — replace before next skin-graft list'),
    ('KIMS Secunderabad','OT-4','PD-KIM-501','Stryker Precision Saw','reciprocating_saw','battery_liion','2026-06-29','2026-06-29 09:05:00+05:30',
     11000,10890,1.00,2.40,2.32,'pass','good',0.06,'pass',249,false,'pending_review','Lubrication step skipped this cycle — hold release pending review'),
    ('Care Hospitals Banjara Hills','OT-2','PD-CAR-601','Medtronic Midas Rex','craniotome','electric_mains','2026-06-28','2026-06-28 08:00:00+05:30',
     75000,74200,1.07,0.90,0.88,'pass','good',0.02,'pass',118,true,'fit_for_use','High-speed craniotome within all limits'),
    ('Yashoda Somajiguda Hyderabad','OT-6','PD-YSH-701','Synthes TRS Recon Drill','ortho_drill','battery_liion','2026-06-28','2026-06-28 09:40:00+05:30',
     1150,1020,11.30,5.80,4.60,'fail','degraded',0.10,'borderline',421,true,'sent_for_repair','Gearbox whine plus torque fail past 400 sterilization cycles — OEM overhaul'),
    ('St John''s Bengaluru','OT-1','PD-STJ-801','Hall PowerPro Drill','ortho_drill','battery_nimh','2026-06-27','2026-06-27 07:15:00+05:30',
     1300,1275,1.92,6.00,5.90,'pass','good',0.05,'pass',187,true,'fit_for_use','Routine audit clean — NiMH pack holding charge'),
    ('Rainbow Children''s Hyderabad','OT-3','PD-RBW-901','Aesculap Microspeed','craniotome','electric_mains','2026-06-27',null,
     60000,null,null,0.80,null,'not_run','good',null,'not_run',73,false,'pending_review','Bench tester unavailable — RPM and torque test deferred')
  ) as q(hosp, ot, tag, model, itype, pwr, td, ts, rr, mr, dev, rt, mt, tv, bhc, cr, crv, scc, lub, av, nt);

  -- CAPA seed — attach to specific instruments by asset tag
  insert into public.surgical_drill_capa_actions_r3222 (
    drill_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('PD-FRT-201','battery_swollen','battery_cell_aging','replace_battery_pack','2026-07-06',null,'in_progress','patient_safety_alert',38500.00,'Li-ion pack swollen — replacement pack on order from Synthes'),
    ('PD-FRT-202','hose_leak','hose_seal_perished','replace_hose_assembly','2026-07-08',null,'open','nabh_finding',21000.00,'Pneumatic hose assembly leaking — line pressure drop 1.2 bar'),
    ('PD-MNP-302','chuck_runout_excess','chuck_bearing_worn','withdraw_instrument','2026-07-04','2026-07-02','closed','iso_13485_deviation',64000.00,'Instrument withdrawn; replacement wire driver issued to OT-4'),
    ('PD-YSH-701','torque_low','gearbox_wear','send_to_oem_service','2026-07-20',null,'escalated','cdsco_notifiable',92000.00,'Torque 21% below rated — OEM gearbox overhaul escalated'),
    ('PD-KIM-501','lubrication_missed','lubricant_not_per_ifu','retrain_technician','2026-07-03','2026-07-01','closed','internal_only',0.00,'CSSD technician retrained on IFU lubrication step'),
    ('PD-APL-102','rpm_deviation','battery_cell_aging','replace_battery_pack','2026-06-30',null,'overdue','nabh_finding',36000.00,'Battery pack replacement overdue — RPM still 7.5% low')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.surgical_drill_r3222 e
    on e.organization_id = v_org_id and e.instrument_asset_tag = q.tag;
end;
$$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3222_verdict_rollup()
returns table(audit_verdict text, instruments bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgical_drill_r3222)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.surgical_drill_r3222 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_verdict_rollup() from public, anon;
grant execute on function public.founder_r3222_verdict_rollup() to authenticated;

-- 2) Hospital-level safety scorecard
create or replace function public.founder_r3222_hospital_scorecard()
returns table(
  hospital_name text,
  total_instruments bigint,
  fit_for_use bigint,
  quarantined bigint,
  withdrawn bigint,
  torque_fail bigint,
  runout_fail bigint,
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
    count(*) filter (where l.audit_verdict = 'quarantined')::bigint,
    count(*) filter (where l.audit_verdict = 'withdrawn')::bigint,
    count(*) filter (where l.torque_verdict = 'fail')::bigint,
    count(*) filter (where l.chuck_runout_verdict = 'fail')::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.surgical_drill_r3222 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3222_hospital_scorecard() to authenticated;

-- 3) Instrument type × power source matrix
create or replace function public.founder_r3222_instrument_type_matrix()
returns table(instrument_type text, power_source text, instruments bigint, fit_for_use bigint, avg_rpm_deviation_pct numeric, avg_sterilization_cycles numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, l.power_source, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.rpm_deviation_pct), 2),
    round(avg(l.sterilization_cycle_count)::numeric, 0)
  from public.surgical_drill_r3222 l
  group by l.instrument_type, l.power_source
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_instrument_type_matrix() from public, anon;
grant execute on function public.founder_r3222_instrument_type_matrix() to authenticated;

-- 4) Daily test trend — torque / runout / lubrication
create or replace function public.founder_r3222_daily_test_trend()
returns table(test_date date, instruments_tested bigint, torque_pass bigint, torque_fail bigint, runout_fail bigint, lubrication_missed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date, count(*)::bigint,
    count(*) filter (where l.torque_verdict = 'pass')::bigint,
    count(*) filter (where l.torque_verdict = 'fail')::bigint,
    count(*) filter (where l.chuck_runout_verdict in ('fail','borderline'))::bigint,
    count(*) filter (where not l.lubrication_done)::bigint
  from public.surgical_drill_r3222 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3222_daily_test_trend() from public, anon;
grant execute on function public.founder_r3222_daily_test_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3222_capa_status_board()
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
  from public.surgical_drill_capa_actions_r3222 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_capa_status_board() from public, anon;
grant execute on function public.founder_r3222_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3222_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgical_drill_capa_actions_r3222)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.surgical_drill_capa_actions_r3222 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3222_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3222_regulatory_impact_digest()
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
  from public.surgical_drill_capa_actions_r3222 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3222_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3222_regulatory_impact_digest() to authenticated;

-- 8) High-risk instruments queue (top individual concerns)
create or replace function public.founder_r3222_high_risk_instruments()
returns table(
  hospital_name text,
  ot_room_code text,
  instrument_asset_tag text,
  instrument_type text,
  test_date date,
  audit_verdict text,
  torque_verdict text,
  chuck_runout_verdict text,
  battery_hose_condition text,
  sterilization_cycle_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.instrument_asset_tag, l.instrument_type, l.test_date,
    l.audit_verdict, l.torque_verdict, l.chuck_runout_verdict, l.battery_hose_condition,
    l.sterilization_cycle_count, l.notes
  from public.surgical_drill_r3222 l
  where l.audit_verdict in ('restricted_use','quarantined','withdrawn','pending_review','sent_for_repair')
     or l.torque_verdict = 'fail'
     or l.chuck_runout_verdict = 'fail'
     or l.battery_hose_condition in ('swollen_battery','cracked_hose','leaking_hose','replace_now')
     or l.sterilization_cycle_count > 400
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3222_high_risk_instruments() from public, anon;
grant execute on function public.founder_r3222_high_risk_instruments() to authenticated;
