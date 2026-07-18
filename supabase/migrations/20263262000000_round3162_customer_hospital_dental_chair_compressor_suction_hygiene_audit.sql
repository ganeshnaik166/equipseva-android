-- Round 3162: Customer Hospital Dental Chair Compressor & Suction-Line Hygiene Audit
-- Dental unit QA log — compressor pressure × oil/moisture × suction flow × amalgam separator ×
-- waterline CFU × anti-retraction valve × handpiece lubrication × verdict × CAPA

-- =============================================================================
-- TABLE 1: dental_chair_r3162 — individual dental chair hygiene audits
-- =============================================================================
create table if not exists public.dental_chair_r3162 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  clinic_room_code text not null,
  chair_asset_tag text not null,
  chair_model text not null,
  audit_number int not null,
  audit_date date not null,
  audited_at timestamptz not null,
  compressor_type text not null check (compressor_type in (
    'oil_lubricated','oil_free_scroll','dry_piston','membrane_diaphragm','central_medical_air'
  )),
  compressor_pressure_bar numeric(4,2),
  oil_moisture_check text not null check (oil_moisture_check in (
    'dry_pass','moisture_trace','moisture_fail','oil_carryover','not_applicable'
  )),
  suction_type text not null check (suction_type in (
    'wet_ring_vacuum','dry_vacuum','semi_dry','central_amalgam','portable_unit'
  )),
  suction_flow_lpm numeric(6,2),
  amalgam_separator_status text not null check (amalgam_separator_status in (
    'iso_11143_compliant','replacement_due','bypass_detected','not_installed','full_alarm_active'
  )),
  waterline_cfu_per_ml int,
  anti_retraction_valve text not null check (anti_retraction_valve in (
    'functional','failed','absent','retrofit_due','not_tested'
  )),
  handpiece_lubrication text not null check (handpiece_lubrication in (
    'automated_pass','manual_pass','overdue','contaminated','not_done'
  )),
  verdict text not null check (verdict in (
    'passed','conditional_pass','failed','quarantined','recall_needed','pending_review'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_chair_r3162 enable row level security;

create index if not exists idx_dental_chair_r3162_org on public.dental_chair_r3162(organization_id);
create index if not exists idx_dental_chair_r3162_date on public.dental_chair_r3162(audit_date);
create index if not exists idx_dental_chair_r3162_verdict on public.dental_chair_r3162(verdict);

-- =============================================================================
-- TABLE 2: dental_chair_capa_actions_r3162 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dental_chair_capa_actions_r3162 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.dental_chair_r3162(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'compressor_moisture','low_air_pressure','suction_flow_low','amalgam_separator_fail',
    'waterline_contamination','anti_retraction_fail','handpiece_lube_overdue','oil_carryover',
    'biofilm_detected','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'air_dryer_saturated','compressor_ring_worn','suction_motor_degraded','separator_cartridge_full',
    'waterline_biofilm','check_valve_stuck','lubrication_skipped','filter_clogged',
    'water_quality_hard','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_air_dryer','rebuild_compressor','service_suction_motor','replace_separator_cartridge',
    'shock_disinfect_waterline','replace_check_valve','retrain_operator','replace_filter',
    'install_water_softener','schedule_amc_visit','none_required'
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

alter table public.dental_chair_capa_actions_r3162 enable row level security;

create index if not exists idx_dental_chair_capa_r3162_audit on public.dental_chair_capa_actions_r3162(audit_id);
create index if not exists idx_dental_chair_capa_r3162_status on public.dental_chair_capa_actions_r3162(capa_status);

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

  -- 14 dental chair audit rows
  insert into public.dental_chair_r3162 (
    organization_id, hospital_name, clinic_room_code, chair_asset_tag, chair_model,
    audit_number, audit_date, audited_at,
    compressor_type, compressor_pressure_bar, oil_moisture_check,
    suction_type, suction_flow_lpm, amalgam_separator_status,
    waterline_cfu_per_ml, anti_retraction_valve, handpiece_lubrication,
    verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.room, q.tag, q.model,
    q.an::int, q.ad::date, q.aud::timestamptz,
    q.ct, q.cp, q.om,
    q.st, q.sf, q.ams,
    q.cfu, q.arv, q.hl,
    q.vd, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','DENT-01','DC-APL-021','A-dec 500','1','2026-07-01','2026-07-01 08:00:00+05:30',
     'oil_free_scroll',5.20,'dry_pass','dry_vacuum',310.00,'iso_11143_compliant',120,'functional','automated_pass','passed','2026-07-01 09:00:00+05:30','Routine QA — all parameters within limits'),
    ('Apollo Hyderabad Jubilee Hills','DENT-02','DC-APL-022','Sirona Intego','2','2026-07-01','2026-07-01 09:30:00+05:30',
     'oil_lubricated',4.80,'moisture_trace','wet_ring_vacuum',295.00,'iso_11143_compliant',180,'functional','manual_pass','conditional_pass','2026-07-01 10:15:00+05:30','Trace moisture at dryer outlet — monitor'),
    ('Fortis Bannerghatta Bengaluru','DENT-01','DC-FRT-014','Planmeca Compact','5','2026-07-01','2026-07-01 07:15:00+05:30',
     'oil_lubricated',3.90,'oil_carryover','dry_vacuum',210.00,'replacement_due',340,'retrofit_due','overdue','failed',null,'Oil carryover + low pressure + separator replacement due'),
    ('Fortis Bannerghatta Bengaluru','DENT-02','DC-FRT-015','A-dec 300','6','2026-07-01','2026-07-01 08:40:00+05:30',
     'oil_free_scroll',5.00,'dry_pass','central_amalgam',180.00,'bypass_detected',520,'failed','contaminated','quarantined',null,'Amalgam separator bypass + waterline CFU 520 — chair quarantined'),
    ('Manipal Whitefield Bengaluru','DENT-03','DC-MNP-031','Sirona Teneo','15','2026-06-30','2026-06-30 10:00:00+05:30',
     'dry_piston',5.40,'dry_pass','dry_vacuum',320.00,'iso_11143_compliant',90,'functional','automated_pass','passed','2026-06-30 11:00:00+05:30','Post-service verification audit'),
    ('Manipal Whitefield Bengaluru','DENT-04','DC-MNP-032','A-dec 500','16','2026-06-30','2026-06-30 11:30:00+05:30',
     'oil_lubricated',4.60,'moisture_fail','wet_ring_vacuum',260.00,'iso_11143_compliant',210,'functional','manual_pass','conditional_pass','2026-06-30 12:15:00+05:30','Moisture fail on dryer — desiccant swap scheduled'),
    ('AIIMS New Delhi Ansari Nagar','DENT-05','DC-AIM-041','Planmeca Compact i5','42','2026-06-30','2026-06-30 07:45:00+05:30',
     'central_medical_air',5.60,'dry_pass','central_amalgam',340.00,'iso_11143_compliant',70,'functional','automated_pass','passed','2026-06-30 08:30:00+05:30','Central plant supply — nominal'),
    ('AIIMS New Delhi Ansari Nagar','DENT-06','DC-AIM-042','Sirona Intego','43','2026-06-30','2026-06-30 09:10:00+05:30',
     'oil_free_scroll',4.20,'moisture_trace','dry_vacuum',190.00,'replacement_due',280,'not_tested','overdue','failed',null,'Suction flow low + separator replacement due'),
    ('KIMS Secunderabad','DENT-02','DC-KIM-018','A-dec 300','28','2026-06-29','2026-06-29 08:20:00+05:30',
     'oil_lubricated',3.60,'oil_carryover','wet_ring_vacuum',205.00,'iso_11143_compliant',160,'functional','manual_pass','conditional_pass','2026-06-29 09:00:00+05:30','Compressor ring wear — oil in line, pressure marginal'),
    ('KIMS Secunderabad','DENT-03','DC-KIM-019','Planmeca Compact','29','2026-06-29','2026-06-29 10:00:00+05:30',
     'dry_piston',5.10,'dry_pass','dry_vacuum',150.00,'full_alarm_active',610,'absent','not_done','recall_needed',null,'Separator full-alarm + no anti-retraction valve — recall for retrofit'),
    ('Care Hospitals Banjara Hills','DENT-01','DC-CAR-007','Sirona Teneo','11','2026-06-29','2026-06-29 09:30:00+05:30',
     'oil_free_scroll',5.30,'dry_pass','dry_vacuum',300.00,'iso_11143_compliant',110,'functional','automated_pass','passed','2026-06-29 10:20:00+05:30','Routine monitored — pass'),
    ('Yashoda Somajiguda Hyderabad','DENT-04','DC-YSH-025','A-dec 500','67','2026-06-28','2026-06-28 08:00:00+05:30',
     'oil_lubricated',4.90,'moisture_trace','central_amalgam',270.00,'iso_11143_compliant',190,'functional','manual_pass','conditional_pass','2026-06-28 08:45:00+05:30','Minor moisture trace — within action limit'),
    ('St John''s Bengaluru','DENT-02','DC-STJ-004','Planmeca Compact','9','2026-06-28','2026-06-28 07:30:00+05:30',
     'dry_piston',5.50,'dry_pass','dry_vacuum',330.00,'iso_11143_compliant',85,'functional','automated_pass','passed','2026-06-28 08:15:00+05:30','Weekly audit — full compliance'),
    ('Rainbow Children''s Hyderabad','DENT-03','DC-RBW-012','Sirona Intego','24','2026-06-27','2026-06-27 09:00:00+05:30',
     'oil_free_scroll',2.80,'moisture_fail','portable_unit',120.00,'not_installed',430,'not_tested','not_done','pending_review',null,'Portable unit low pressure + no separator installed — under review')
  ) as q(hosp, room, tag, model, an, ad, aud, ct, cp, om, st, sf, ams, cfu, arv, hl, vd, rel, nt)
  where q.an ~ '^[0-9]+$';

  -- CAPA seed — attach to specific audits
  insert into public.dental_chair_capa_actions_r3162 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select c.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 5, 'oil_carryover','compressor_ring_worn','rebuild_compressor','2026-07-06',null,'in_progress','nabh_finding',38000.00,'Piston ring kit ordered — oil ingress into air line'),
    ('Fortis Bannerghatta Bengaluru', 6, 'amalgam_separator_fail','separator_cartridge_full','replace_separator_cartridge','2026-07-04',null,'escalated','cdsco_notifiable',22000.00,'Bypass detected — CDSCO reportable, chair down'),
    ('AIIMS New Delhi Ansari Nagar',  43, 'suction_flow_low','suction_motor_degraded','service_suction_motor','2026-07-05',null,'open','iso_13485_deviation',15000.00,'Flow 190 lpm below 250 target'),
    ('KIMS Secunderabad',             29, 'anti_retraction_fail','check_valve_stuck','replace_check_valve','2026-07-03',null,'escalated','patient_safety_alert',8500.00,'No anti-retraction valve — cross-contamination risk, recall'),
    ('KIMS Secunderabad',             28, 'low_air_pressure','compressor_ring_worn','rebuild_compressor','2026-07-07','2026-07-02','closed','internal_only',36000.00,'Ring replaced, pressure restored to 5.2 bar'),
    ('Rainbow Children''s Hyderabad',  24, 'waterline_contamination','waterline_biofilm','shock_disinfect_waterline','2026-07-08',null,'open','nabh_finding',6000.00,'CFU 430 — shock disinfection + separator install')
  ) as q(hosp_key, an_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.dental_chair_r3162 c
    on c.hospital_name = q.hosp_key and c.audit_number = q.an_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution
create or replace function public.founder_r3162_verdict_rollup()
returns table(verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_chair_r3162)
  select l.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dental_chair_r3162 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_verdict_rollup() from public, anon;
grant execute on function public.founder_r3162_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3162_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  quarantined bigint,
  recalls bigint,
  waterline_alerts bigint,
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
    count(*) filter (where l.verdict = 'passed')::bigint,
    count(*) filter (where l.verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.verdict = 'failed')::bigint,
    count(*) filter (where l.verdict = 'quarantined')::bigint,
    count(*) filter (where l.verdict = 'recall_needed')::bigint,
    count(*) filter (where l.waterline_cfu_per_ml > 200)::bigint,
    round(100.0 * count(*) filter (where l.verdict = 'passed')::numeric / nullif(count(*),0), 1)
  from public.dental_chair_r3162 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3162_hospital_scorecard() to authenticated;

-- 3) Compressor-type × suction-type matrix
create or replace function public.founder_r3162_compressor_suction_matrix()
returns table(
  compressor_type text,
  suction_type text,
  audits bigint,
  passed bigint,
  avg_pressure_bar numeric,
  avg_suction_lpm numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.compressor_type, l.suction_type, count(*)::bigint,
    count(*) filter (where l.verdict = 'passed')::bigint,
    round(avg(l.compressor_pressure_bar), 2),
    round(avg(l.suction_flow_lpm), 1)
  from public.dental_chair_r3162 l
  group by l.compressor_type, l.suction_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_compressor_suction_matrix() from public, anon;
grant execute on function public.founder_r3162_compressor_suction_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3162_audit_daily_trend()
returns table(
  audit_date date,
  total_audits bigint,
  passed bigint,
  failed bigint,
  waterline_alerts bigint,
  avg_suction_lpm numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.verdict = 'passed')::bigint,
    count(*) filter (where l.verdict in ('failed','quarantined','recall_needed'))::bigint,
    count(*) filter (where l.waterline_cfu_per_ml > 200)::bigint,
    round(avg(l.suction_flow_lpm), 1)
  from public.dental_chair_r3162 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3162_audit_daily_trend() from public, anon;
grant execute on function public.founder_r3162_audit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3162_capa_status_board()
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
  from public.dental_chair_capa_actions_r3162 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_capa_status_board() from public, anon;
grant execute on function public.founder_r3162_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3162_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_chair_capa_actions_r3162)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dental_chair_capa_actions_r3162 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3162_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3162_regulatory_impact_digest()
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
  from public.dental_chair_capa_actions_r3162 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3162_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3162_regulatory_impact_digest() to authenticated;

-- 8) High-risk audits queue (top individual concerns)
create or replace function public.founder_r3162_high_risk_audits()
returns table(
  hospital_name text,
  clinic_room_code text,
  chair_asset_tag text,
  audit_date date,
  verdict text,
  oil_moisture_check text,
  amalgam_separator_status text,
  anti_retraction_valve text,
  waterline_cfu_per_ml int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.clinic_room_code, l.chair_asset_tag, l.audit_date,
    l.verdict, l.oil_moisture_check, l.amalgam_separator_status, l.anti_retraction_valve,
    l.waterline_cfu_per_ml, l.notes
  from public.dental_chair_r3162 l
  where l.verdict in ('failed','quarantined','recall_needed','pending_review','conditional_pass')
     or l.oil_moisture_check in ('moisture_fail','oil_carryover')
     or l.amalgam_separator_status in ('bypass_detected','not_installed','full_alarm_active')
     or l.anti_retraction_valve in ('failed','absent')
     or l.waterline_cfu_per_ml > 200
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3162_high_risk_audits() from public, anon;
grant execute on function public.founder_r3162_high_risk_audits() to authenticated;
