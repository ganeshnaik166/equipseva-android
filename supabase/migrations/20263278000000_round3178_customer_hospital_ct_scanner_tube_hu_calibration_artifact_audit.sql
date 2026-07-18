-- Round 3178: Customer Hospital CT-Scanner Tube-Warmup, HU-Calibration & Artifact Audit
-- CT QA log — scanner model × tube warmup × air-cal HU offset × water-phantom HU × noise SD × artifact type × slice thickness × CTDIvol dose × CAPA

-- =============================================================================
-- TABLE 1: ct_scanner_qa_r3178 — individual CT scanner QA check runs
-- =============================================================================
create table if not exists public.ct_scanner_qa_r3178 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ct_room_code text not null,
  scanner_asset_tag text not null,
  scanner_model text not null,
  qa_check_number int not null,
  qa_date date not null,
  qa_started_at timestamptz not null,
  tube_warmup_done boolean not null default false,
  warmup_protocol text not null check (warmup_protocol in (
    'full_warmup_ifu','short_warmup','auto_warmup','skipped_emergency','not_required_recent_use'
  )),
  air_cal_hu_offset numeric(6,2),
  water_phantom_hu numeric(6,2),
  water_phantom_verdict text check (water_phantom_verdict in (
    'within_tolerance','out_of_tolerance','borderline','not_run'
  )),
  noise_sd_hu numeric(5,2),
  noise_verdict text check (noise_verdict in ('pass','fail','borderline','not_run')),
  artifact_type text not null check (artifact_type in (
    'ring','streak','beam_hardening','cone_beam','motion_ghost','none'
  )),
  artifact_severity text not null check (artifact_severity in ('none','minor','moderate','severe')),
  slice_thickness_check text check (slice_thickness_check in ('pass','fail','marginal','not_run')),
  ctdivol_mgy numeric(6,2),
  dose_within_drl boolean not null default true,
  operator_profile_id uuid references public.profiles(id) on delete set null,
  qa_verdict text not null check (qa_verdict in (
    'cleared_for_use','restricted_use','out_of_service','recalibration_needed','pending_physicist_review','conditional_clearance'
  )),
  cleared_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ct_scanner_qa_r3178 enable row level security;

create index if not exists idx_ct_qa_r3178_org on public.ct_scanner_qa_r3178(organization_id);
create index if not exists idx_ct_qa_r3178_date on public.ct_scanner_qa_r3178(qa_date);
create index if not exists idx_ct_qa_r3178_verdict on public.ct_scanner_qa_r3178(qa_verdict);

-- =============================================================================
-- TABLE 2: ct_scanner_qa_capa_actions_r3178 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ct_scanner_qa_capa_actions_r3178 (
  id uuid primary key default gen_random_uuid(),
  qa_log_id uuid not null references public.ct_scanner_qa_r3178(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'hu_calibration_drift','ring_artifact','streak_artifact','beam_hardening',
    'excess_noise','tube_warmup_skipped','slice_thickness_fail','dose_above_drl',
    'detector_channel_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'tube_aging','detector_element_dead','misaligned_collimator','calibration_overdue',
    'bow_tie_filter_damage','cooling_system_degraded','operator_protocol_error',
    'software_recon_fault','power_quality_issue','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'run_full_air_calibration','replace_xray_tube','replace_detector_module',
    'realign_collimator','replace_bow_tie_filter','service_cooling_system',
    'retrain_technologist','update_recon_software','schedule_amc_visit','escalate_to_oem','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','cdsco_notifiable','none','internal_only','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ct_scanner_qa_capa_actions_r3178 enable row level security;

create index if not exists idx_ct_qa_capa_r3178_log on public.ct_scanner_qa_capa_actions_r3178(qa_log_id);
create index if not exists idx_ct_qa_capa_r3178_status on public.ct_scanner_qa_capa_actions_r3178(capa_status);

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

  -- 14 QA check rows
  insert into public.ct_scanner_qa_r3178 (
    organization_id, hospital_name, ct_room_code, scanner_asset_tag, scanner_model,
    qa_check_number, qa_date, qa_started_at,
    tube_warmup_done, warmup_protocol, air_cal_hu_offset,
    water_phantom_hu, water_phantom_verdict, noise_sd_hu, noise_verdict,
    artifact_type, artifact_severity, slice_thickness_check,
    ctdivol_mgy, dose_within_drl, qa_verdict, cleared_at, notes
  )
  select v_org_id, q.hosp, q.room, q.tag, q.model,
    q.qn, q.qd::date, q.qs::timestamptz,
    q.wu, q.wp, q.aco,
    q.wph, q.wpv, q.nsd, q.nv,
    q.art, q.asv, q.stc,
    q.dose, q.drl, q.qv, q.cl::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CT-1','CT-APL-021','GE Revolution Apex',1,'2026-07-10','2026-07-10 06:00:00+05:30',
     true,'full_warmup_ifu',1.20,0.80,'within_tolerance',4.10,'pass','none','none','pass',12.40,true,'cleared_for_use','2026-07-10 06:40:00+05:30','Morning QA all within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','CT-1','CT-APL-021','GE Revolution Apex',2,'2026-07-11','2026-07-11 06:05:00+05:30',
     true,'auto_warmup',1.50,1.10,'within_tolerance',4.30,'pass','none','none','pass',12.60,true,'cleared_for_use','2026-07-11 06:45:00+05:30','Routine daily QA'),
    ('Fortis Bannerghatta Bengaluru','CT-2','CT-FRT-009','Siemens Somatom go.Top',5,'2026-07-11','2026-07-11 05:45:00+05:30',
     true,'full_warmup_ifu',6.80,5.90,'out_of_tolerance',5.20,'borderline','ring','moderate','pass',13.10,true,'recalibration_needed',null,'HU drift +5.9 with faint ring — detector suspect'),
    ('Fortis Bannerghatta Bengaluru','CT-2','CT-FRT-009','Siemens Somatom go.Top',6,'2026-07-12','2026-07-12 06:10:00+05:30',
     true,'full_warmup_ifu',2.10,1.60,'within_tolerance',4.40,'pass','none','none','pass',12.90,true,'cleared_for_use','2026-07-12 06:50:00+05:30','Post air-cal recheck passed'),
    ('Manipal Whitefield Bengaluru','CT-1','CT-MNP-014','Philips Incisive CT',12,'2026-07-09','2026-07-09 07:00:00+05:30',
     false,'skipped_emergency',3.40,2.20,'borderline',6.10,'fail','streak','minor','marginal',14.80,false,'restricted_use',null,'Warmup skipped for trauma case — noise SD above 6'),
    ('Manipal Whitefield Bengaluru','CT-1','CT-MNP-014','Philips Incisive CT',13,'2026-07-10','2026-07-10 06:20:00+05:30',
     true,'full_warmup_ifu',1.80,1.30,'within_tolerance',4.60,'pass','none','none','pass',13.00,true,'cleared_for_use','2026-07-10 07:00:00+05:30','Recovered after full warmup and air cal'),
    ('AIIMS New Delhi Ansari Nagar','CT-3','CT-AIM-041','Siemens Somatom Force',88,'2026-07-08','2026-07-08 05:30:00+05:30',
     true,'full_warmup_ifu',8.90,7.40,'out_of_tolerance',7.30,'fail','ring','severe','fail',16.20,false,'out_of_service',null,'Severe ring + water HU 7.4 — physics pulled scanner from service'),
    ('AIIMS New Delhi Ansari Nagar','CT-3','CT-AIM-041','Siemens Somatom Force',89,'2026-07-12','2026-07-12 09:00:00+05:30',
     true,'full_warmup_ifu',1.10,0.60,'within_tolerance',3.90,'pass','none','none','pass',12.10,true,'cleared_for_use','2026-07-12 09:45:00+05:30','Cleared after detector module replacement'),
    ('KIMS Secunderabad','CT-1','CT-KIM-006','Canon Aquilion Prime SP',31,'2026-07-09','2026-07-09 06:15:00+05:30',
     true,'short_warmup',2.90,2.70,'borderline',5.00,'borderline','beam_hardening','minor','pass',15.40,false,'pending_physicist_review',null,'Beam hardening near posterior fossa — physicist review'),
    ('KIMS Secunderabad','CT-1','CT-KIM-006','Canon Aquilion Prime SP',32,'2026-07-12','2026-07-12 06:00:00+05:30',
     true,'full_warmup_ifu',5.70,4.90,'out_of_tolerance',4.90,'pass','beam_hardening','moderate','pass',15.90,false,'recalibration_needed',null,'CTDIvol above paediatric DRL and HU drift persists'),
    ('Care Hospitals Banjara Hills','CT-2','CT-CAR-012','GE Optima CT660',19,'2026-07-08','2026-07-08 07:30:00+05:30',
     true,'full_warmup_ifu',2.40,1.90,'within_tolerance',4.80,'pass','none','none','pass',13.60,true,'cleared_for_use','2026-07-08 08:10:00+05:30','Routine QA nominal'),
    ('Yashoda Somajiguda Hyderabad','CT-1','CT-YSH-027','Philips Spectral CT 7500',54,'2026-07-07','2026-07-07 06:40:00+05:30',
     true,'auto_warmup',4.60,3.80,'borderline',5.60,'borderline','streak','moderate','pass',14.10,true,'conditional_clearance','2026-07-07 07:30:00+05:30','Streaks from metal calibration insert — cleared with limits'),
    ('St John''s Bengaluru','CT-2','CT-STJ-004','Siemens Somatom go.Now',16,'2026-07-07','2026-07-07 05:55:00+05:30',
     true,'full_warmup_ifu',1.60,1.20,'within_tolerance',4.20,'pass','none','none','pass',12.70,true,'cleared_for_use','2026-07-07 06:35:00+05:30','Weekly full QA including slice thickness'),
    ('Rainbow Children''s Hyderabad','CT-1','CT-RBW-008','GE Revolution Ascend',22,'2026-07-06','2026-07-06 07:10:00+05:30',
     false,'not_required_recent_use',2.00,1.70,'within_tolerance',4.50,'pass','motion_ghost','minor','not_run',9.80,true,'conditional_clearance','2026-07-06 07:40:00+05:30','Paediatric protocol — motion ghost on phantom repositioning')
  ) as q(hosp, room, tag, model, qn, qd, qs, wu, wp, aco, wph, wpv, nsd, nv, art, asv, stc, dose, drl, qv, cl, nt);

  -- CAPA seed — attach to specific QA checks
  insert into public.ct_scanner_qa_capa_actions_r3178 (
    qa_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('AIIMS New Delhi Ansari Nagar',88,'ring_artifact','detector_element_dead','replace_detector_module','2026-07-11','2026-07-12','closed','aerb_notifiable',420000.00,'Detector module swapped under OEM warranty share'),
    ('AIIMS New Delhi Ansari Nagar',88,'hu_calibration_drift','detector_element_dead','run_full_air_calibration','2026-07-12','2026-07-12','closed','patient_safety_alert',0.00,'Full air cal after module replacement — water HU back to 0.6'),
    ('Fortis Bannerghatta Bengaluru',5,'hu_calibration_drift','calibration_overdue','run_full_air_calibration','2026-07-12','2026-07-12','closed','nabh_finding',8500.00,'Quarterly air calibration was 18 days overdue'),
    ('Manipal Whitefield Bengaluru',12,'tube_warmup_skipped','operator_protocol_error','retrain_technologist','2026-07-15',null,'in_progress','internal_only',0.00,'Night-shift technologists retraining on warmup SOP'),
    ('KIMS Secunderabad',31,'beam_hardening','bow_tie_filter_damage','replace_bow_tie_filter','2026-07-18',null,'verification_pending','cdsco_notifiable',96000.00,'Filter replaced — physicist verification scan pending'),
    ('KIMS Secunderabad',32,'dose_above_drl','operator_protocol_error','retrain_technologist','2026-07-20',null,'escalated','aerb_notifiable',0.00,'Paediatric CTDIvol above AERB DRL twice — escalated to radiology head'),
    ('Yashoda Somajiguda Hyderabad',54,'streak_artifact','software_recon_fault','update_recon_software','2026-07-10',null,'overdue','internal_only',35000.00,'Recon patch from OEM awaited — overdue 8 days'),
    ('Rainbow Children''s Hyderabad',22,'preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-25',null,'open','none',18000.00,'Half-yearly PM due — AMC visit slot requested')
  ) as q(hosp_key, qn_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.ct_scanner_qa_r3178 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp_key and e.qa_check_number = q.qn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QA verdict distribution
create or replace function public.founder_r3178_qa_verdict_rollup()
returns table(qa_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ct_scanner_qa_r3178)
  select l.qa_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ct_scanner_qa_r3178 l
  group by l.qa_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_qa_verdict_rollup() from public, anon;
grant execute on function public.founder_r3178_qa_verdict_rollup() to authenticated;

-- 2) Hospital-level QA scorecard
create or replace function public.founder_r3178_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  cleared bigint,
  restricted bigint,
  out_of_service bigint,
  hu_out_of_tolerance bigint,
  artifact_flagged bigint,
  warmup_skipped bigint,
  clearance_pct numeric
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
    count(*) filter (where l.qa_verdict = 'cleared_for_use')::bigint,
    count(*) filter (where l.qa_verdict = 'restricted_use')::bigint,
    count(*) filter (where l.qa_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.water_phantom_verdict = 'out_of_tolerance')::bigint,
    count(*) filter (where l.artifact_type <> 'none')::bigint,
    count(*) filter (where not l.tube_warmup_done)::bigint,
    round(100.0 * count(*) filter (where l.qa_verdict = 'cleared_for_use')::numeric / nullif(count(*),0), 1)
  from public.ct_scanner_qa_r3178 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3178_hospital_scorecard() to authenticated;

-- 3) Artifact type × severity matrix
create or replace function public.founder_r3178_artifact_matrix()
returns table(artifact_type text, artifact_severity text, checks bigint, avg_noise_sd numeric, avg_water_hu numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.artifact_type, l.artifact_severity, count(*)::bigint,
    round(avg(l.noise_sd_hu), 2),
    round(avg(l.water_phantom_hu), 2)
  from public.ct_scanner_qa_r3178 l
  group by l.artifact_type, l.artifact_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_artifact_matrix() from public, anon;
grant execute on function public.founder_r3178_artifact_matrix() to authenticated;

-- 4) HU calibration + dose daily trend
create or replace function public.founder_r3178_hu_dose_daily_trend()
returns table(qa_date date, checks bigint, avg_water_hu numeric, avg_noise_sd numeric, avg_ctdivol_mgy numeric, drl_breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.qa_date, count(*)::bigint,
    round(avg(l.water_phantom_hu), 2),
    round(avg(l.noise_sd_hu), 2),
    round(avg(l.ctdivol_mgy), 2),
    count(*) filter (where not l.dose_within_drl)::bigint
  from public.ct_scanner_qa_r3178 l
  group by l.qa_date
  order by l.qa_date desc;
end;
$$;

revoke execute on function public.founder_r3178_hu_dose_daily_trend() from public, anon;
grant execute on function public.founder_r3178_hu_dose_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3178_capa_status_board()
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
  from public.ct_scanner_qa_capa_actions_r3178 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_capa_status_board() from public, anon;
grant execute on function public.founder_r3178_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3178_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ct_scanner_qa_capa_actions_r3178)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ct_scanner_qa_capa_actions_r3178 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3178_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3178_regulatory_impact_digest()
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
  from public.ct_scanner_qa_capa_actions_r3178 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3178_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3178_regulatory_impact_digest() to authenticated;

-- 8) High-risk QA checks list (top individual concerns)
create or replace function public.founder_r3178_high_risk_checks()
returns table(
  hospital_name text,
  ct_room_code text,
  scanner_asset_tag text,
  qa_date date,
  qa_verdict text,
  water_phantom_verdict text,
  noise_verdict text,
  artifact_type text,
  slice_thickness_check text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ct_room_code, l.scanner_asset_tag, l.qa_date,
    l.qa_verdict, l.water_phantom_verdict, l.noise_verdict, l.artifact_type, l.slice_thickness_check, l.notes
  from public.ct_scanner_qa_r3178 l
  where l.qa_verdict in ('restricted_use','out_of_service','recalibration_needed','pending_physicist_review','conditional_clearance')
     or l.water_phantom_verdict = 'out_of_tolerance'
     or l.noise_verdict = 'fail'
     or l.artifact_type <> 'none'
     or l.slice_thickness_check = 'fail'
     or not l.tube_warmup_done
  order by l.qa_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3178_high_risk_checks() from public, anon;
grant execute on function public.founder_r3178_high_risk_checks() to authenticated;
