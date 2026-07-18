-- Round 3167: Customer Hospital Ultrasound Probe Disinfection & Image-Quality Audit
-- US probe QA log — probe type × disinfection level/method × reprocessing × crystal drop-out × image uniformity × lens/cable integrity × verdict + CAPA

-- =============================================================================
-- TABLE 1: ultrasound_probe_r3167 — individual probe disinfection & QA audits
-- =============================================================================
create table if not exists public.ultrasound_probe_r3167 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department text not null,
  ultrasound_room_code text not null,
  probe_asset_tag text not null,
  probe_model text not null,
  probe_type text not null check (probe_type in (
    'linear_array','curved_convex','phased_sector','endocavitary_tvs',
    'transesophageal_tee','microconvex','volume_3d_4d','pencil_cw'
  )),
  clinical_application text not null check (clinical_application in (
    'abdominal','obstetric_gynae','cardiac_echo','vascular_doppler',
    'small_parts_msk','transvaginal','transesophageal','pediatric'
  )),
  audit_date date not null,
  audit_started_at timestamptz not null,
  audit_completed_at timestamptz,
  disinfection_level text not null check (disinfection_level in (
    'high_level_disinfection','intermediate_level','low_level_wipe','sterilization','not_performed'
  )),
  disinfection_method text not null check (disinfection_method in (
    'trophon_h2o2','cidex_opa_soak','glutaraldehyde_soak','sterrad_plasma',
    'uv_c_cabinet','wipe_quaternary','wipe_alcohol','sterile_sheath_only'
  )),
  reprocessing_method text not null check (reprocessing_method in (
    'spaulding_semicritical','spaulding_critical','spaulding_noncritical',
    'manual_clean_hld','automated_reprocessor','point_of_care_wipe'
  )),
  disinfection_contact_time_min int,
  crystal_dropout_pct numeric(5,2),
  image_uniformity text not null check (image_uniformity in (
    'uniform','mild_nonuniformity','visible_banding','element_dropout','severe_degradation'
  )),
  lens_condition text not null check (lens_condition in (
    'intact','minor_scratch','lens_crack','delamination','membrane_bulge','fluid_ingress'
  )),
  cable_integrity text not null check (cable_integrity in (
    'intact','kinked','cracked_sheath','exposed_conductor','strain_relief_damaged'
  )),
  electrical_leakage_ua numeric(6,2),
  verdict text not null check (verdict in (
    'passed','conditional_pass','quarantined','failed','retired','recall_needed','pending_review'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ultrasound_probe_r3167 enable row level security;

create index if not exists idx_ultrasound_probe_r3167_org on public.ultrasound_probe_r3167(organization_id);
create index if not exists idx_ultrasound_probe_r3167_date on public.ultrasound_probe_r3167(audit_date);
create index if not exists idx_ultrasound_probe_r3167_verdict on public.ultrasound_probe_r3167(verdict);

-- =============================================================================
-- TABLE 2: ultrasound_probe_capa_actions_r3167 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ultrasound_probe_capa_actions_r3167 (
  id uuid primary key default gen_random_uuid(),
  probe_audit_id uuid not null references public.ultrasound_probe_r3167(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'crystal_dropout','image_nonuniformity','lens_crack','cable_damage',
    'disinfection_lapse','electrical_leakage_high','contact_time_short',
    'probe_contamination','reprocessing_deviation','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mechanical_impact_drop','age_wear_degradation','improper_reprocessing',
    'chemical_incompatibility','operator_handling_error','cable_flex_fatigue',
    'fluid_ingress_seal_fail','disinfectant_expired','trophon_cartridge_low',
    'pending_investigation','maintenance_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_probe','send_for_repair','recalibrate_probe','retrain_operator',
    'requarantine_probe','replace_cable','revise_reprocessing_sop',
    'swap_disinfectant_stock','schedule_amc_visit','trigger_recall','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only',
    'iso_13485_deviation','patient_safety_alert','infection_control_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ultrasound_probe_capa_actions_r3167 enable row level security;

create index if not exists idx_ultrasound_probe_capa_r3167_audit on public.ultrasound_probe_capa_actions_r3167(probe_audit_id);
create index if not exists idx_ultrasound_probe_capa_r3167_status on public.ultrasound_probe_capa_actions_r3167(capa_status);

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

  -- 14 probe audit rows
  insert into public.ultrasound_probe_r3167 (
    organization_id, hospital_name, department, ultrasound_room_code, probe_asset_tag, probe_model,
    probe_type, clinical_application, audit_date, audit_started_at, audit_completed_at,
    disinfection_level, disinfection_method, reprocessing_method, disinfection_contact_time_min,
    crystal_dropout_pct, image_uniformity, lens_condition, cable_integrity, electrical_leakage_ua,
    verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.dept, q.room, q.tag, q.model,
    q.ptype, q.app, q.ad::date, q.ast::timestamptz, q.act::timestamptz,
    q.dlvl, q.dmeth, q.rmeth, q.cont,
    q.cdo, q.iu, q.lc, q.ci, q.leak,
    q.vd, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Radiology','USG-1','PRB-APL-L12','GE C1-6',
     'curved_convex','abdominal','2026-07-15','2026-07-15 08:00:00+05:30','2026-07-15 08:20:00+05:30',
     'high_level_disinfection','trophon_h2o2','spaulding_semicritical',7,
     1.50,'uniform','intact','intact',4.20,
     'passed','2026-07-15 08:30:00+05:30','Routine abdominal probe HLD passed'),
    ('Apollo Hyderabad Jubilee Hills','Radiology','USG-1','PRB-APL-L07','GE 9L-D',
     'linear_array','small_parts_msk','2026-07-15','2026-07-15 09:00:00+05:30','2026-07-15 09:15:00+05:30',
     'high_level_disinfection','wipe_quaternary','spaulding_semicritical',2,
     6.80,'mild_nonuniformity','minor_scratch','intact',8.50,
     'conditional_pass','2026-07-15 09:25:00+05:30','Minor lens scratch, dropout under threshold'),
    ('Fortis Bannerghatta Bengaluru','Cardiology','ECHO-2','PRB-FRT-TEE3','Philips X8-2t',
     'transesophageal_tee','transesophageal','2026-07-15','2026-07-15 07:30:00+05:30','2026-07-15 08:10:00+05:30',
     'high_level_disinfection','cidex_opa_soak','spaulding_semicritical',12,
     14.20,'element_dropout','lens_crack','cracked_sheath',45.00,
     'quarantined',null,'TEE element dropout and lens crack — bite injury suspected'),
    ('Fortis Bannerghatta Bengaluru','Obstetrics','USG-3','PRB-FRT-TVS5','Samsung EV-10',
     'endocavitary_tvs','transvaginal','2026-07-14','2026-07-14 10:00:00+05:30','2026-07-14 10:20:00+05:30',
     'high_level_disinfection','trophon_h2o2','spaulding_semicritical',7,
     3.10,'uniform','intact','kinked',6.00,
     'conditional_pass','2026-07-14 10:30:00+05:30','Cable kink near strain relief flagged for monitoring'),
    ('Manipal Whitefield Bengaluru','Radiology','USG-2','PRB-MNP-C09','Mindray SC6-1',
     'curved_convex','obstetric_gynae','2026-07-14','2026-07-14 08:45:00+05:30','2026-07-14 09:05:00+05:30',
     'high_level_disinfection','trophon_h2o2','spaulding_semicritical',7,
     22.50,'severe_degradation','delamination','exposed_conductor',120.00,
     'failed',null,'Severe crystal dropout and delamination — probe removed from service'),
    ('Manipal Whitefield Bengaluru','Vascular Lab','USG-4','PRB-MNP-L15','Mindray L12-3',
     'linear_array','vascular_doppler','2026-07-14','2026-07-14 09:30:00+05:30','2026-07-14 09:45:00+05:30',
     'high_level_disinfection','wipe_alcohol','spaulding_semicritical',3,
     1.20,'uniform','intact','intact',3.80,
     'passed','2026-07-14 09:55:00+05:30','Vascular linear probe clean bill'),
    ('AIIMS New Delhi Ansari Nagar','Cardiology','ECHO-5','PRB-AIM-P33','GE M5S-D',
     'phased_sector','cardiac_echo','2026-07-13','2026-07-13 06:30:00+05:30','2026-07-13 06:50:00+05:30',
     'low_level_wipe','wipe_quaternary','spaulding_noncritical',2,
     0.80,'uniform','intact','intact',2.50,
     'passed','2026-07-13 07:00:00+05:30','Surface echo probe low-level wipe adequate'),
    ('AIIMS New Delhi Ansari Nagar','Radiology','USG-6','PRB-AIM-V21','Canon PVI-475BX',
     'volume_3d_4d','obstetric_gynae','2026-07-13','2026-07-13 07:15:00+05:30','2026-07-13 07:40:00+05:30',
     'high_level_disinfection','trophon_h2o2','spaulding_semicritical',7,
     9.40,'visible_banding','minor_scratch','intact',12.00,
     'conditional_pass','2026-07-13 07:50:00+05:30','4D volume probe banding, scheduled for factory service'),
    ('KIMS Secunderabad','Radiology','USG-4','PRB-KIM-C11','Philips C5-1',
     'curved_convex','abdominal','2026-07-12','2026-07-12 05:45:00+05:30','2026-07-12 06:05:00+05:30',
     'intermediate_level','glutaraldehyde_soak','manual_clean_hld',20,
     4.60,'mild_nonuniformity','intact','intact',7.20,
     'conditional_pass','2026-07-12 06:15:00+05:30','Glutaraldehyde soak contact time adequate'),
    ('KIMS Secunderabad','Emergency','USG-7','PRB-KIM-L18','Sonosite HFL38',
     'linear_array','vascular_doppler','2026-07-12','2026-07-12 07:00:00+05:30','2026-07-12 07:12:00+05:30',
     'low_level_wipe','wipe_quaternary','point_of_care_wipe',1,
     5.50,'mild_nonuniformity','minor_scratch','strain_relief_damaged',15.00,
     'quarantined',null,'POCUS probe strain relief damaged, disinfection contact time short'),
    ('Care Hospitals Banjara Hills','Gastroenterology','USG-2','PRB-CAR-TEE2','GE 6VT-D',
     'transesophageal_tee','transesophageal','2026-07-11','2026-07-11 09:00:00+05:30','2026-07-11 09:35:00+05:30',
     'high_level_disinfection','sterrad_plasma','spaulding_critical',55,
     2.10,'uniform','intact','intact',5.00,
     'passed','2026-07-11 09:45:00+05:30','TEE Sterrad plasma sterilization cycle passed'),
    ('Yashoda Somajiguda Hyderabad','Radiology','USG-6','PRB-YSH-MC08','Hitachi C41L47',
     'microconvex','pediatric','2026-07-10','2026-07-10 06:30:00+05:30','2026-07-10 06:48:00+05:30',
     'high_level_disinfection','trophon_h2o2','spaulding_semicritical',7,
     7.90,'mild_nonuniformity','intact','intact',9.00,
     'conditional_pass','2026-07-10 06:58:00+05:30','Pediatric microconvex borderline dropout'),
    ('St John''s Bengaluru','Radiology','USG-1','PRB-STJ-L03','GE L2-9',
     'linear_array','small_parts_msk','2026-07-10','2026-07-10 05:50:00+05:30','2026-07-10 06:05:00+05:30',
     'high_level_disinfection','uv_c_cabinet','spaulding_semicritical',3,
     1.00,'uniform','intact','intact',3.20,
     'passed','2026-07-10 06:15:00+05:30','UV-C cabinet reprocessing full pass'),
    ('Rainbow Children''s Hyderabad','Neonatology','USG-3','PRB-RBW-P09','Philips S12-4',
     'phased_sector','pediatric','2026-07-09','2026-07-09 07:00:00+05:30',null,
     'not_performed','sterile_sheath_only','point_of_care_wipe',null,
     null,'uniform','membrane_bulge','intact',null,
     'pending_review',null,'Neonatal probe membrane bulge, fluid ingress check pending')
  ) as q(hosp, dept, room, tag, model, ptype, app, ad, ast, act, dlvl, dmeth, rmeth, cont, cdo, iu, lc, ci, leak, vd, rel, nt);

  -- CAPA seed — attach to specific probes by asset tag
  insert into public.ultrasound_probe_capa_actions_r3167 (
    probe_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PRB-FRT-TEE3','lens_crack','mechanical_impact_drop','send_for_repair','2026-07-22',null,'in_progress','patient_safety_alert',185000.00,'TEE probe sent to GE for lens and element repair; loaner arranged'),
    ('PRB-MNP-C09','crystal_dropout','age_wear_degradation','replace_probe','2026-07-25',null,'escalated','cdsco_notifiable',425000.00,'Probe beyond economic repair — capital replacement approved'),
    ('PRB-KIM-L18','cable_damage','cable_flex_fatigue','replace_cable','2026-07-20','2026-07-16','closed','iso_13485_deviation',32000.00,'Cable and strain relief replaced, retested pass'),
    ('PRB-FRT-TVS5','cable_damage','operator_handling_error','retrain_operator','2026-07-19',null,'open','internal_only',8000.00,'Sonographer retrained on probe cable handling'),
    ('PRB-AIM-V21','image_nonuniformity','age_wear_degradation','send_for_repair','2026-07-28',null,'in_progress','none',95000.00,'4D volume probe factory service for banding'),
    ('PRB-RBW-P09','disinfection_lapse','improper_reprocessing','revise_reprocessing_sop','2026-07-21',null,'open','infection_control_alert',5000.00,'Neonatal probe reprocessing SOP revision and fluid ingress inspection')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.ultrasound_probe_r3167 e
    on e.organization_id = v_org_id and e.probe_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution
create or replace function public.founder_r3167_verdict_rollup()
returns table(verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ultrasound_probe_r3167)
  select l.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ultrasound_probe_r3167 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_verdict_rollup() from public, anon;
grant execute on function public.founder_r3167_verdict_rollup() to authenticated;

-- 2) Hospital-level QA scorecard
create or replace function public.founder_r3167_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  quarantined bigint,
  failed bigint,
  lens_cracks bigint,
  cable_faults bigint,
  high_dropout bigint,
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
    count(*) filter (where l.verdict = 'passed')::bigint,
    count(*) filter (where l.verdict = 'quarantined')::bigint,
    count(*) filter (where l.verdict in ('failed','retired','recall_needed'))::bigint,
    count(*) filter (where l.lens_condition in ('lens_crack','delamination','fluid_ingress'))::bigint,
    count(*) filter (where l.cable_integrity in ('cracked_sheath','exposed_conductor','strain_relief_damaged'))::bigint,
    count(*) filter (where l.crystal_dropout_pct >= 10)::bigint,
    round(100.0 * count(*) filter (where l.verdict = 'passed')::numeric / nullif(count(*),0), 1)
  from public.ultrasound_probe_r3167 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3167_hospital_scorecard() to authenticated;

-- 3) Probe type × disinfection level matrix
create or replace function public.founder_r3167_probe_type_matrix()
returns table(probe_type text, disinfection_level text, audits bigint, passed bigint, avg_dropout numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.probe_type, l.disinfection_level, count(*)::bigint,
    count(*) filter (where l.verdict in ('passed','conditional_pass'))::bigint,
    round(avg(l.crystal_dropout_pct), 2)
  from public.ultrasound_probe_r3167 l
  group by l.probe_type, l.disinfection_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_probe_type_matrix() from public, anon;
grant execute on function public.founder_r3167_probe_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3167_daily_trend()
returns table(audit_date date, audits bigint, passed bigint, quarantined bigint, failed bigint, avg_dropout numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.verdict in ('passed','conditional_pass'))::bigint,
    count(*) filter (where l.verdict = 'quarantined')::bigint,
    count(*) filter (where l.verdict in ('failed','retired','recall_needed'))::bigint,
    round(avg(l.crystal_dropout_pct), 2)
  from public.ultrasound_probe_r3167 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3167_daily_trend() from public, anon;
grant execute on function public.founder_r3167_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3167_capa_status_board()
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
  from public.ultrasound_probe_capa_actions_r3167 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_capa_status_board() from public, anon;
grant execute on function public.founder_r3167_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3167_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ultrasound_probe_capa_actions_r3167)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ultrasound_probe_capa_actions_r3167 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3167_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3167_regulatory_impact_digest()
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
  from public.ultrasound_probe_capa_actions_r3167 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3167_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3167_regulatory_impact_digest() to authenticated;

-- 8) High-risk probes priority queue
create or replace function public.founder_r3167_high_risk_queue()
returns table(
  hospital_name text,
  ultrasound_room_code text,
  probe_asset_tag text,
  probe_type text,
  audit_date date,
  verdict text,
  image_uniformity text,
  lens_condition text,
  cable_integrity text,
  crystal_dropout_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ultrasound_room_code, l.probe_asset_tag, l.probe_type, l.audit_date,
    l.verdict, l.image_uniformity, l.lens_condition, l.cable_integrity, l.crystal_dropout_pct, l.notes
  from public.ultrasound_probe_r3167 l
  where l.verdict in ('quarantined','failed','retired','recall_needed','pending_review','conditional_pass')
     or l.lens_condition in ('lens_crack','delamination','membrane_bulge','fluid_ingress')
     or l.cable_integrity in ('cracked_sheath','exposed_conductor','strain_relief_damaged')
     or l.image_uniformity in ('visible_banding','element_dropout','severe_degradation')
     or l.crystal_dropout_pct >= 10
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3167_high_risk_queue() from public, anon;
grant execute on function public.founder_r3167_high_risk_queue() to authenticated;
