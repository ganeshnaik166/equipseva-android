-- Round 3182: Customer Hospital OT Integration Video-Tower & Insufflator Function Audit
-- Laparoscopy tower QA — component × white-balance × light output % × CO2 flow accuracy × pressure-relief × image lag × cable/seal integrity × CAPA

-- =============================================================================
-- TABLE 1: ot_video_tower_r3182 — individual video-tower / insufflator audits
-- =============================================================================
create table if not exists public.ot_video_tower_r3182 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  tower_asset_tag text not null,
  tower_model text not null,
  audit_ref text not null,
  audit_date date not null,
  audited_at timestamptz not null,
  component text not null check (component in (
    'camera_head','camera_control_unit','light_source','insufflator',
    'surgical_monitor','recorder_capture','co2_supply_line','tower_cart'
  )),
  white_balance_result text check (white_balance_result in (
    'pass','fail','drift_warning','not_applicable'
  )),
  light_output_pct numeric(5,2),
  co2_flow_set_lpm numeric(5,2),
  co2_flow_measured_lpm numeric(5,2),
  co2_flow_accuracy_pct numeric(5,2),
  pressure_relief_test text check (pressure_relief_test in (
    'pass','fail','sluggish_release','not_run','not_applicable'
  )),
  image_lag_ms int,
  cable_integrity text not null check (cable_integrity in (
    'intact','frayed','connector_damaged','intermittent_fault','replaced'
  )),
  seal_integrity text check (seal_integrity in (
    'intact','leaking','worn','replaced','not_applicable'
  )),
  firmware_version text,
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','conditional_pass','restricted_use','recheck_required','pending_parts','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_video_tower_r3182 enable row level security;

create index if not exists idx_ot_video_tower_r3182_org on public.ot_video_tower_r3182(organization_id);
create index if not exists idx_ot_video_tower_r3182_date on public.ot_video_tower_r3182(audit_date);
create index if not exists idx_ot_video_tower_r3182_verdict on public.ot_video_tower_r3182(audit_verdict);

-- =============================================================================
-- TABLE 2: ot_video_tower_capa_actions_r3182 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_video_tower_capa_actions_r3182 (
  id uuid primary key default gen_random_uuid(),
  tower_audit_id uuid not null references public.ot_video_tower_r3182(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'white_balance_fail','light_output_low','co2_flow_inaccurate','pressure_relief_fail',
    'image_lag_excessive','cable_fault','seal_leak','recorder_failure','firmware_outdated','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_module_aged','light_cable_fiber_broken','insufflator_valve_worn','flow_sensor_drift',
    'camera_head_moisture_ingress','monitor_panel_degraded','cable_strain_damage','seal_gasket_worn',
    'firmware_bug','operator_handling_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_lamp_module','replace_light_cable','rebuild_insufflator_valve','recalibrate_flow_sensor',
    'send_camera_head_oem_repair','replace_monitor_panel','replace_cable_assembly','replace_seal_kit',
    'update_firmware','retrain_operator','schedule_amc_visit','none_required'
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

alter table public.ot_video_tower_capa_actions_r3182 enable row level security;

create index if not exists idx_ot_vt_capa_r3182_audit on public.ot_video_tower_capa_actions_r3182(tower_audit_id);
create index if not exists idx_ot_vt_capa_r3182_status on public.ot_video_tower_capa_actions_r3182(capa_status);

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

  -- 14 tower-audit rows
  insert into public.ot_video_tower_r3182 (
    organization_id, hospital_name, ot_room_code, tower_asset_tag, tower_model,
    audit_ref, audit_date, audited_at, component, white_balance_result,
    light_output_pct, co2_flow_set_lpm, co2_flow_measured_lpm, co2_flow_accuracy_pct,
    pressure_relief_test, image_lag_ms, cable_integrity, seal_integrity,
    firmware_version, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.ref, q.ad::date, q.ats::timestamptz, q.comp, q.wb,
    q.lo, q.cfs, q.cfm, q.cfa,
    q.prt, q.il, q.ci, q.si,
    q.fw, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-2','VT-APL-101','Karl Storz Image1 S','VTA-0001','2026-07-02','2026-07-02 06:30:00+05:30',
     'camera_head','pass',null,null,null,null,'not_applicable',42,'intact','not_applicable','IMG1-4.2.1','fit_for_use','Annual QA — image crisp, white balance locked'),
    ('Apollo Hyderabad Jubilee Hills','OT-2','VT-APL-101','Karl Storz Image1 S','VTA-0002','2026-07-02','2026-07-02 06:55:00+05:30',
     'insufflator','not_applicable',null,20.00,19.60,98.00,'pass',null,'intact','intact','ENDOFLATOR-2.8','fit_for_use','CO2 flow within 2 pct of setpoint; relief valve crisp'),
    ('Fortis Bannerghatta Bengaluru','OT-4','VT-FRT-207','Olympus Visera Elite II','VTA-0003','2026-07-01','2026-07-01 07:10:00+05:30',
     'insufflator','not_applicable',null,30.00,25.80,86.00,'sluggish_release',null,'intact','worn','UHI-4-1.9','out_of_service','Flow 14 pct low and relief valve sluggish — tower pulled from OT'),
    ('Fortis Bannerghatta Bengaluru','OT-4','VT-FRT-207','Olympus Visera Elite II','VTA-0004','2026-07-01','2026-07-01 07:40:00+05:30',
     'light_source','not_applicable',58.00,null,null,null,'not_applicable',null,'frayed','not_applicable','CLV-S200-1.4','restricted_use','Lamp at 58 pct output and cable fraying — replace before next list'),
    ('Manipal Whitefield Bengaluru','OT-1','VT-MNP-114','Stryker 1688 AIM 4K','VTA-0005','2026-06-30','2026-06-30 08:05:00+05:30',
     'camera_head','drift_warning',null,null,null,null,'not_applicable',65,'intact','not_applicable','1688-3.1.0','recheck_required','White balance drifts after 30 min warm-up — moisture ingress suspected'),
    ('Manipal Whitefield Bengaluru','OT-1','VT-MNP-114','Stryker 1688 AIM 4K','VTA-0006','2026-06-30','2026-06-30 08:35:00+05:30',
     'surgical_monitor','not_applicable',null,null,null,null,'not_applicable',18,'intact','not_applicable','VP-4K-2.0','fit_for_use','4K monitor 18 ms lag — well inside 50 ms limit'),
    ('AIIMS New Delhi Ansari Nagar','OT-7','VT-AIM-310','Karl Storz Rubina 4K','VTA-0007','2026-06-29','2026-06-29 06:20:00+05:30',
     'recorder_capture','not_applicable',null,null,null,null,'not_applicable',null,'connector_damaged','not_applicable','AIDA-1.5.2','pending_parts','Recorder HDMI input dead — capture card on order'),
    ('AIIMS New Delhi Ansari Nagar','OT-7','VT-AIM-310','Karl Storz Rubina 4K','VTA-0008','2026-06-29','2026-06-29 06:50:00+05:30',
     'insufflator','not_applicable',null,40.00,39.40,98.50,'pass',null,'intact','intact','ENDOFLATOR50-3.0','fit_for_use','High-flow 40 lpm verified for bariatric list'),
    ('KIMS Secunderabad','OT-3','VT-KIM-052','Olympus Visera 4K UHD','VTA-0009','2026-06-28','2026-06-28 07:00:00+05:30',
     'camera_control_unit','fail',null,null,null,null,'not_applicable',130,'intact','not_applicable','OTV-S400-3.2','out_of_service','WB fail plus 130 ms pipeline lag — CCU fault'),
    ('KIMS Secunderabad','OT-3','VT-KIM-052','Olympus Visera 4K UHD','VTA-0010','2026-06-28','2026-06-28 07:30:00+05:30',
     'co2_supply_line','not_applicable',null,null,null,null,'fail',null,'intact','leaking',null,'out_of_service','Audible CO2 leak at line seal; relief valve failed to lift'),
    ('Care Hospitals Banjara Hills','OT-2','VT-CAR-021','Stryker 1588 AIM','VTA-0011','2026-06-27','2026-06-27 09:15:00+05:30',
     'light_source','not_applicable',82.50,null,null,null,'not_applicable',null,'intact','not_applicable','L11-2.2','conditional_pass','Lamp at 82.5 pct — above action level, recheck monthly'),
    ('Yashoda Somajiguda Hyderabad','OT-5','VT-YSH-077','Karl Storz Image1 S','VTA-0012','2026-06-27','2026-06-27 06:40:00+05:30',
     'insufflator','not_applicable',null,15.00,14.90,99.30,'pass',null,'intact','intact','ENDOFLATOR-2.8','fit_for_use','Paediatric low-flow profile verified'),
    ('St John''s Bengaluru','OT-1','VT-STJ-009','Olympus Visera Elite','VTA-0013','2026-06-26','2026-06-26 07:20:00+05:30',
     'tower_cart','not_applicable',null,null,null,null,'not_applicable',null,'intermittent_fault','not_applicable',null,'recheck_required','Cart mains cable drops out under flex — isolation transformer suspected'),
    ('Rainbow Children''s Hyderabad','OT-2','VT-RBW-033','Stryker 1688 AIM 4K','VTA-0014','2026-06-25','2026-06-25 08:10:00+05:30',
     'surgical_monitor','not_applicable',null,null,null,null,'not_applicable',95,'intact','not_applicable','VP-4K-1.8','restricted_use','Monitor lag 95 ms — above 50 ms laparoscopy limit, backup monitor in use')
  ) as q(hosp, ot, tag, model, ref, ad, ats, comp, wb, lo, cfs, cfm, cfa, prt, il, ci, si, fw, vd, nt);

  -- CAPA seed — attach to specific audits via audit_ref
  insert into public.ot_video_tower_capa_actions_r3182 (
    tower_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('VTA-0003','co2_flow_inaccurate','insufflator_valve_worn','rebuild_insufflator_valve','2026-07-08',null,'in_progress','patient_safety_alert',68000.00,'Valve kit air-shipped from Olympus'),
    ('VTA-0004','light_output_low','lamp_module_aged','replace_lamp_module','2026-07-06','2026-07-04','closed','internal_only',24000.00,'New lamp module fitted — output back to 97 pct'),
    ('VTA-0005','white_balance_fail','camera_head_moisture_ingress','send_camera_head_oem_repair','2026-07-20',null,'open','iso_13485_deviation',145000.00,'Loaner camera head issued while OEM repairs original'),
    ('VTA-0009','image_lag_excessive','firmware_bug','update_firmware','2026-07-05',null,'verification_pending','nabh_finding',0.00,'CCU flashed 3.2 to 3.4 — lag retest scheduled'),
    ('VTA-0010','seal_leak','seal_gasket_worn','replace_seal_kit','2026-07-03',null,'escalated','patient_safety_alert',8500.00,'CO2 leak inside OT — escalated to biomedical head'),
    ('VTA-0013','cable_fault','cable_strain_damage','replace_cable_assembly','2026-06-28',null,'overdue','internal_only',12500.00,'Replacement cable PO stuck in approval — overdue'),
    ('VTA-0007','recorder_failure','pending_investigation','schedule_amc_visit','2026-07-12',null,'open','none',55000.00,'OEM engineer visit booked for capture card swap')
  ) as q(ref, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.ot_video_tower_r3182 e
    on e.organization_id = v_org_id and e.audit_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3182_audit_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_video_tower_r3182)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_video_tower_r3182 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3182_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level tower-health scorecard
create or replace function public.founder_r3182_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  restricted bigint,
  out_of_service bigint,
  wb_issues bigint,
  avg_light_output_pct numeric,
  avg_image_lag_ms numeric,
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
    count(*) filter (where l.audit_verdict = 'restricted_use')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.white_balance_result in ('fail','drift_warning'))::bigint,
    round(avg(l.light_output_pct), 1),
    round(avg(l.image_lag_ms)::numeric, 0),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.ot_video_tower_r3182 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3182_hospital_scorecard() to authenticated;

-- 3) Component-level audit matrix
create or replace function public.founder_r3182_component_matrix()
returns table(component text, audits bigint, fit_for_use bigint, wb_issues bigint, avg_co2_accuracy_pct numeric, avg_image_lag_ms numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.component, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.white_balance_result in ('fail','drift_warning'))::bigint,
    round(avg(l.co2_flow_accuracy_pct), 2),
    round(avg(l.image_lag_ms)::numeric, 0)
  from public.ot_video_tower_r3182 l
  group by l.component
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_component_matrix() from public, anon;
grant execute on function public.founder_r3182_component_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3182_daily_trend()
returns table(audit_date date, audits bigint, fit_for_use bigint, out_of_service bigint, wb_issues bigint, pressure_fails bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.white_balance_result in ('fail','drift_warning'))::bigint,
    count(*) filter (where l.pressure_relief_test in ('fail','sluggish_release'))::bigint
  from public.ot_video_tower_r3182 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3182_daily_trend() from public, anon;
grant execute on function public.founder_r3182_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3182_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees), 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ot_video_tower_capa_actions_r3182 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_capa_status_board() from public, anon;
grant execute on function public.founder_r3182_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3182_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_video_tower_capa_actions_r3182)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_video_tower_capa_actions_r3182 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3182_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3182_regulatory_impact_digest()
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
  from public.ot_video_tower_capa_actions_r3182 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3182_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3182_regulatory_impact_digest() to authenticated;

-- 8) High-risk audits queue (top individual concerns)
create or replace function public.founder_r3182_high_risk_audits()
returns table(
  hospital_name text,
  ot_room_code text,
  tower_asset_tag text,
  component text,
  audit_date date,
  audit_verdict text,
  white_balance_result text,
  pressure_relief_test text,
  image_lag_ms int,
  seal_integrity text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.tower_asset_tag, l.component, l.audit_date,
    l.audit_verdict, l.white_balance_result, l.pressure_relief_test, l.image_lag_ms, l.seal_integrity, l.notes
  from public.ot_video_tower_r3182 l
  where l.audit_verdict in ('restricted_use','recheck_required','pending_parts','out_of_service')
     or l.white_balance_result in ('fail','drift_warning')
     or l.pressure_relief_test in ('fail','sluggish_release')
     or l.seal_integrity = 'leaking'
     or l.image_lag_ms > 50
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3182_high_risk_audits() from public, anon;
grant execute on function public.founder_r3182_high_risk_audits() to authenticated;
