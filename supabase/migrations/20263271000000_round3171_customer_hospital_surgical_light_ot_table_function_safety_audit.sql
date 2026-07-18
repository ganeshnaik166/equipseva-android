-- Round 3171: Customer Hospital Surgical Light & OT-Table Function-Safety Audit
-- OT light/table QA log — asset type × illuminance/colour-temp × backup-bulb/handle × table load/motor/tilt/brake × verdict × CAPA

-- =============================================================================
-- TABLE 1: ot_light_table_r3171 — individual surgical-light / OT-table safety audits
-- =============================================================================
create table if not exists public.ot_light_table_r3171 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  asset_tag text not null,
  asset_model text not null,
  asset_type text not null check (asset_type in (
    'surgical_light_ceiling','surgical_light_mobile','surgical_light_examination',
    'ot_table_hydraulic','ot_table_electric','ot_table_mechanical'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  illuminance_lux_at_1m int,
  colour_temperature_k int,
  backup_bulb_status text not null check (backup_bulb_status in (
    'present_functional','present_failed','absent','not_applicable'
  )),
  sterilisable_handle_status text not null check (sterilisable_handle_status in (
    'present_intact','present_damaged','absent','not_applicable'
  )),
  table_load_capacity_kg numeric(6,2),
  motor_function_status text not null check (motor_function_status in (
    'smooth','noisy','intermittent','failed','not_applicable'
  )),
  tilt_trendelenburg_status text not null check (tilt_trendelenburg_status in (
    'full_range','limited_range','stuck','failed','not_applicable'
  )),
  brake_lock_status text not null check (brake_lock_status in (
    'holds_firmly','slips','failed','not_applicable'
  )),
  verdict text not null check (verdict in (
    'pass','conditional_pass','fail','out_of_service','pending_review','recall_needed'
  )),
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_light_table_r3171 enable row level security;

create index if not exists idx_ot_light_table_r3171_org on public.ot_light_table_r3171(organization_id);
create index if not exists idx_ot_light_table_r3171_date on public.ot_light_table_r3171(audit_date);
create index if not exists idx_ot_light_table_r3171_verdict on public.ot_light_table_r3171(verdict);

-- =============================================================================
-- TABLE 2: ot_light_table_capa_actions_r3171 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_light_table_capa_actions_r3171 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.ot_light_table_r3171(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_illuminance','colour_temp_drift','backup_bulb_failure','handle_contamination',
    'motor_failure','tilt_mechanism_fault','brake_slippage','load_capacity_derated',
    'structural_corrosion','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_module_aged','bulb_end_of_life','handle_sterilisation_wear','hydraulic_seal_leak',
    'motor_brush_worn','gear_backlash','brake_pad_worn','control_board_fault',
    'wiring_insulation_degraded','frame_corrosion','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_led_module','replace_backup_bulb','replace_sterilisable_handle','reseal_hydraulic_cylinder',
    'replace_drive_motor','recalibrate_tilt_sensor','replace_brake_assembly','replace_control_board',
    'schedule_amc_visit','none_required','derate_and_label_load_limit'
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

alter table public.ot_light_table_capa_actions_r3171 enable row level security;

create index if not exists idx_ot_light_table_capa_r3171_audit on public.ot_light_table_capa_actions_r3171(audit_id);
create index if not exists idx_ot_light_table_capa_r3171_status on public.ot_light_table_capa_actions_r3171(capa_status);

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

  -- 13 audit rows across real Indian hospitals
  insert into public.ot_light_table_r3171 (
    organization_id, hospital_name, ot_room_code, asset_tag, asset_model, asset_type,
    audit_date, audited_at, illuminance_lux_at_1m, colour_temperature_k,
    backup_bulb_status, sterilisable_handle_status, table_load_capacity_kg,
    motor_function_status, tilt_trendelenburg_status, brake_lock_status,
    verdict, verified_at, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model, q.atype,
    q.ad::date, q.aud::timestamptz, q.lux, q.ctk,
    q.bulb, q.handle, q.loadkg,
    q.motor, q.tilt, q.brake,
    q.verdict, q.ver::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-3','SL-APL-031','Trumpf TruLight 5000','surgical_light_ceiling',
     '2026-07-10','2026-07-10 06:30:00+05:30',160000,4400,'present_functional','present_intact',null,
     'not_applicable','not_applicable','not_applicable','pass','2026-07-10 07:00:00+05:30','Central field 160 klux, sterilisable handle intact'),
    ('Apollo Hyderabad Jubilee Hills','OT-3','OT-APL-012','Maquet Alphamaquet 1150','ot_table_electric',
     '2026-07-10','2026-07-10 07:15:00+05:30',null,null,'not_applicable','not_applicable',360.00,
     'smooth','full_range','holds_firmly','pass','2026-07-10 07:45:00+05:30','Load 360 kg, all motions smooth'),
    ('Fortis Bannerghatta Bengaluru','OT-1','SL-FRT-018','Skytron Aurora','surgical_light_ceiling',
     '2026-07-09','2026-07-09 05:40:00+05:30',85000,4300,'present_functional','present_intact',null,
     'not_applicable','not_applicable','not_applicable','conditional_pass','2026-07-09 06:10:00+05:30','Illuminance 85 klux below 100 klux minimum — LED module ageing'),
    ('Fortis Bannerghatta Bengaluru','OT-1','OT-FRT-007','Steris Cmax','ot_table_electric',
     '2026-07-09','2026-07-09 06:30:00+05:30',null,null,'not_applicable','not_applicable',320.00,
     'failed','limited_range','holds_firmly','out_of_service',null,'Drive motor dead — table stuck, tagged out of service'),
    ('Manipal Whitefield Bengaluru','OT-2','SL-MNP-022','Hillrom TruLight mobile','surgical_light_mobile',
     '2026-07-08','2026-07-08 08:20:00+05:30',110000,4500,'present_failed','present_intact',null,
     'not_applicable','not_applicable','not_applicable','conditional_pass','2026-07-08 08:50:00+05:30','Primary OK but backup bulb failed to strike'),
    ('Manipal Whitefield Bengaluru','OT-2','OT-MNP-014','Mizuho MOT-6801','ot_table_hydraulic',
     '2026-07-08','2026-07-08 09:10:00+05:30',null,null,'not_applicable','not_applicable',300.00,
     'noisy','full_range','slips','fail',null,'Brake fails to hold on tilt — patient-safety risk'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','SL-AIM-045','Draeger Polaris 600','surgical_light_ceiling',
     '2026-07-07','2026-07-07 06:05:00+05:30',150000,4200,'present_functional','present_intact',null,
     'not_applicable','not_applicable','not_applicable','pass','2026-07-07 06:35:00+05:30','Full compliance, shadow control verified'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','OT-AIM-033','Trumpf Saturn Selecto','ot_table_electric',
     '2026-07-07','2026-07-07 07:00:00+05:30',null,null,'not_applicable','not_applicable',454.00,
     'smooth','limited_range','holds_firmly','conditional_pass','2026-07-07 07:30:00+05:30','Trendelenburg limited range — tilt sensor recalibration due'),
    ('KIMS Secunderabad','OT-4','SL-KIM-011','Philips Burton OuterLight','surgical_light_examination',
     '2026-07-06','2026-07-06 05:50:00+05:30',95000,4600,'present_functional','present_damaged',null,
     'not_applicable','not_applicable','not_applicable','conditional_pass','2026-07-06 06:20:00+05:30','Sterilisable handle cracked — replacement ordered'),
    ('Care Hospitals Banjara Hills','OT-2','OT-CAR-006','Skytron 6500 Hercules','ot_table_mechanical',
     '2026-07-06','2026-07-06 09:15:00+05:30',null,null,'not_applicable','not_applicable',180.00,
     'intermittent','limited_range','holds_firmly','fail',null,'Load capacity derated to 180 kg due to frame corrosion'),
    ('Yashoda Somajiguda Hyderabad','OT-6','SL-YSH-019','Trumpf TruLight 3000','surgical_light_ceiling',
     '2026-07-05','2026-07-05 06:40:00+05:30',140000,5200,'present_functional','present_intact',null,
     'not_applicable','not_applicable','not_applicable','conditional_pass','2026-07-05 07:10:00+05:30','Colour temp drifted to 5200 K above 4500 K target'),
    ('St John''s Bengaluru','OT-1','OT-STJ-004','Maquet Yuno OTN','ot_table_electric',
     '2026-07-05','2026-07-05 05:55:00+05:30',null,null,'not_applicable','not_applicable',250.00,
     'smooth','full_range','holds_firmly','pass','2026-07-05 06:25:00+05:30','All checks passed, brake firm'),
    ('Rainbow Children''s Hyderabad','OT-3','SL-RBW-009','Hillrom TruLight mobile','surgical_light_mobile',
     '2026-07-04','2026-07-04 07:05:00+05:30',20000,3800,'absent','present_damaged',null,
     'not_applicable','not_applicable','not_applicable','out_of_service',null,'LED module failure — 20 klux only, backup bulb absent, withdrawn')
  ) as q(hosp, ot, tag, model, atype, ad, aud, lux, ctk, bulb, handle, loadkg, motor, tilt, brake, verdict, ver, nt);

  -- CAPA seed — attach to specific audits by asset tag
  insert into public.ot_light_table_capa_actions_r3171 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('SL-FRT-018','low_illuminance','led_module_aged','replace_led_module','2026-07-16',null,'in_progress','nabh_finding',45000.00,'LED module ageing — replacement scheduled'),
    ('OT-FRT-007','motor_failure','motor_brush_worn','replace_drive_motor','2026-07-14',null,'escalated','patient_safety_alert',85000.00,'Drive motor dead — table out of service, urgent'),
    ('OT-MNP-014','brake_slippage','brake_pad_worn','replace_brake_assembly','2026-07-15',null,'open','patient_safety_alert',32000.00,'Brake slips on tilt — replace assembly'),
    ('OT-CAR-006','load_capacity_derated','frame_corrosion','derate_and_label_load_limit','2026-07-20',null,'in_progress','iso_13485_deviation',28000.00,'Frame corrosion — load derated to 180 kg pending repair'),
    ('SL-RBW-009','backup_bulb_failure','led_module_aged','replace_led_module','2026-07-12','2026-07-11','closed','cdsco_notifiable',60000.00,'LED module replaced, unit returned to service'),
    ('SL-MNP-022','backup_bulb_failure','bulb_end_of_life','replace_backup_bulb','2026-07-13',null,'verification_pending','internal_only',3500.00,'Backup bulb replaced, awaiting strike test')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.ot_light_table_r3171 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution
create or replace function public.founder_r3171_verdict_rollup()
returns table(verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_light_table_r3171)
  select l.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_light_table_r3171 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_verdict_rollup() from public, anon;
grant execute on function public.founder_r3171_verdict_rollup() to authenticated;

-- 2) Hospital-level function-safety scorecard
create or replace function public.founder_r3171_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_service bigint,
  avg_illuminance_lux numeric,
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
    count(*) filter (where l.verdict = 'pass')::bigint,
    count(*) filter (where l.verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.verdict = 'fail')::bigint,
    count(*) filter (where l.verdict = 'out_of_service')::bigint,
    round(avg(l.illuminance_lux_at_1m)::numeric, 0),
    round(100.0 * count(*) filter (where l.verdict in ('pass','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.ot_light_table_r3171 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3171_hospital_scorecard() to authenticated;

-- 3) Asset-type category matrix
create or replace function public.founder_r3171_asset_type_matrix()
returns table(
  asset_type text,
  audits bigint,
  passed bigint,
  failed bigint,
  avg_illuminance_lux numeric,
  avg_load_kg numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, count(*)::bigint,
    count(*) filter (where l.verdict = 'pass')::bigint,
    count(*) filter (where l.verdict in ('fail','out_of_service'))::bigint,
    round(avg(l.illuminance_lux_at_1m)::numeric, 0),
    round(avg(l.table_load_capacity_kg)::numeric, 2)
  from public.ot_light_table_r3171 l
  group by l.asset_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_asset_type_matrix() from public, anon;
grant execute on function public.founder_r3171_asset_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3171_audit_daily_trend()
returns table(audit_date date, audits bigint, passed bigint, failed bigint, out_of_service bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.verdict = 'pass')::bigint,
    count(*) filter (where l.verdict = 'fail')::bigint,
    count(*) filter (where l.verdict = 'out_of_service')::bigint
  from public.ot_light_table_r3171 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3171_audit_daily_trend() from public, anon;
grant execute on function public.founder_r3171_audit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3171_capa_status_board()
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
  from public.ot_light_table_capa_actions_r3171 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_capa_status_board() from public, anon;
grant execute on function public.founder_r3171_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3171_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_light_table_capa_actions_r3171)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_light_table_capa_actions_r3171 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3171_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3171_regulatory_impact_digest()
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
  from public.ot_light_table_capa_actions_r3171 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3171_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3171_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue
create or replace function public.founder_r3171_high_risk_queue()
returns table(
  hospital_name text,
  ot_room_code text,
  asset_tag text,
  asset_type text,
  audit_date date,
  verdict text,
  motor_function_status text,
  tilt_trendelenburg_status text,
  brake_lock_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.asset_tag, l.asset_type, l.audit_date,
    l.verdict, l.motor_function_status, l.tilt_trendelenburg_status, l.brake_lock_status, l.notes
  from public.ot_light_table_r3171 l
  where l.verdict in ('conditional_pass','fail','out_of_service','pending_review','recall_needed')
     or l.motor_function_status = 'failed'
     or l.brake_lock_status = 'slips'
     or l.tilt_trendelenburg_status in ('stuck','failed')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3171_high_risk_queue() from public, anon;
grant execute on function public.founder_r3171_high_risk_queue() to authenticated;
