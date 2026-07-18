-- Round 3151: Customer Hospital C-Arm / Fluoroscopy Radiation-Output & Dose Audit
-- C-arm dose QA log — imaging mode × kVp/mA × dose-rate × cumulative dose × collimation × laser × lead-apron × AERB compliance × verdict × CAPA

-- =============================================================================
-- TABLE 1: carm_dose_r3151 — individual C-arm / fluoroscopy dose QA tests
-- =============================================================================
create table if not exists public.carm_dose_r3151 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  cath_lab_code text not null,
  carm_asset_tag text not null,
  carm_model text not null,
  test_number int not null,
  test_date date not null,
  test_started_at timestamptz not null,
  test_ended_at timestamptz,
  imaging_mode text not null check (imaging_mode in (
    'fluoro_low','fluoro_normal','fluoro_high','dsa','cine','roadmap','digital_spot'
  )),
  clinical_procedure text not null check (clinical_procedure in (
    'cardiac_angiography','pci_intervention','peripheral_angioplasty','neuro_intervention',
    'orthopedic_fixation','ercp_biliary','urology_pcnl','pain_management'
  )),
  kvp_setting numeric(5,2) not null,
  ma_setting numeric(6,2),
  dose_rate_mgy_min numeric(7,2) not null,
  cumulative_dose_mgy numeric(9,2) not null,
  fluoro_time_min numeric(6,2),
  dap_gycm2 numeric(9,2),
  collimation_check text not null check (collimation_check in (
    'pass','fail','partial','not_checked'
  )),
  laser_alignment_check text not null check (laser_alignment_check in (
    'aligned','misaligned','not_applicable','not_checked'
  )),
  lead_apron_check text not null check (lead_apron_check in (
    'intact','cracked_minor','cracked_major','missing','not_checked'
  )),
  aerb_compliance text not null check (aerb_compliance in (
    'compliant','non_compliant','conditional','license_expired','pending_renewal'
  )),
  dose_verdict text not null check (dose_verdict in (
    'within_limits','exceeds_drl','quarantined','service_required','recall_needed','pending_review','conditional_pass'
  )),
  released_at timestamptz,
  operator_profile_id uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.carm_dose_r3151 enable row level security;

create index if not exists idx_carm_dose_r3151_org on public.carm_dose_r3151(organization_id);
create index if not exists idx_carm_dose_r3151_date on public.carm_dose_r3151(test_date);
create index if not exists idx_carm_dose_r3151_verdict on public.carm_dose_r3151(dose_verdict);

-- =============================================================================
-- TABLE 2: carm_dose_capa_actions_r3151 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.carm_dose_capa_actions_r3151 (
  id uuid primary key default gen_random_uuid(),
  dose_log_id uuid not null references public.carm_dose_r3151(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dose_exceeds_drl','collimation_fail','laser_misalignment','lead_apron_defect',
    'aerb_non_compliance','kvp_deviation','output_drift','qa_overdue','operator_technique','license_lapse'
  )),
  root_cause text not null check (root_cause in (
    'tube_aging','generator_drift','collimator_fault','calibration_overdue',
    'operator_technique_error','apron_wear','aerb_paperwork_lapse','software_config_error',
    'detector_degradation','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','replace_xray_tube','service_collimator','replace_lead_apron',
    'renew_aerb_license','retrain_operator','optimize_protocol','schedule_amc_visit',
    'quarantine_unit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','patient_dose_alert','staff_safety_alert',
    'internal_only','none','iso_deviation'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.carm_dose_capa_actions_r3151 enable row level security;

create index if not exists idx_carm_dose_capa_r3151_log on public.carm_dose_capa_actions_r3151(dose_log_id);
create index if not exists idx_carm_dose_capa_r3151_status on public.carm_dose_capa_actions_r3151(capa_status);

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

  -- 14 dose QA test rows
  insert into public.carm_dose_r3151 (
    organization_id, hospital_name, cath_lab_code, carm_asset_tag, carm_model,
    test_number, test_date, test_started_at, test_ended_at,
    imaging_mode, clinical_procedure, kvp_setting, ma_setting, dose_rate_mgy_min,
    cumulative_dose_mgy, fluoro_time_min, dap_gycm2,
    collimation_check, laser_alignment_check, lead_apron_check, aerb_compliance,
    dose_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.lab, q.tag, q.model,
    q.tn::int, q.td::date, q.ts::timestamptz, q.te::timestamptz,
    q.mode, q.proc, q.kvp, q.ma, q.dr, q.cd, q.ft, q.dap,
    q.col, q.laser, q.apron, q.aerb,
    q.verdict, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CATH-1','CARM-APL-021','Philips Azurion 7','5','2026-07-02','2026-07-02 09:10:00+05:30','2026-07-02 09:45:00+05:30',
     'dsa','cardiac_angiography',82.00,250.00,28.50,420.00,12.50,45.20,'pass','aligned','intact','compliant','within_limits','2026-07-02 10:00:00+05:30','Routine coronary angiogram, dose within cardiac DRL'),
    ('Apollo Hyderabad Jubilee Hills','CATH-1','CARM-APL-021','Philips Azurion 7','6','2026-07-02','2026-07-02 10:15:00+05:30','2026-07-02 11:05:00+05:30',
     'cine','pci_intervention',90.00,400.00,95.00,1850.00,28.00,220.50,'pass','aligned','intact','compliant','conditional_pass','2026-07-02 11:20:00+05:30','Complex multi-vessel PCI, high but justified dose'),
    ('Fortis Bannerghatta Bengaluru','CATH-2','CARM-FRT-014','GE Innova IGS 520','12','2026-07-01','2026-07-01 08:20:00+05:30','2026-07-01 09:10:00+05:30',
     'fluoro_high','peripheral_angioplasty',88.00,320.00,145.00,2650.00,42.00,380.00,'partial','aligned','cracked_minor','compliant','exceeds_drl',null,'Dose-rate 145 mGy/min exceeds high-mode DRL — tube output review'),
    ('Fortis Bannerghatta Bengaluru','CATH-2','CARM-FRT-014','GE Innova IGS 520','13','2026-07-01','2026-07-01 09:30:00+05:30','2026-07-01 10:25:00+05:30',
     'roadmap','neuro_intervention',75.00,200.00,32.00,980.00,35.00,120.00,'fail','misaligned','cracked_minor','conditional','service_required',null,'Collimation fail plus laser misalignment — unit flagged for service'),
    ('Manipal Whitefield Bengaluru','CATH-1','CARM-MNP-008','Siemens Artis Zee','22','2026-06-30','2026-06-30 07:40:00+05:30','2026-06-30 08:15:00+05:30',
     'dsa','cardiac_angiography',80.00,260.00,26.00,510.00,15.00,52.00,'pass','aligned','intact','compliant','within_limits','2026-06-30 08:30:00+05:30','Diagnostic angiogram, all QA parameters nominal'),
    ('Manipal Whitefield Bengaluru','CATH-1','CARM-MNP-008','Siemens Artis Zee','23','2026-06-30','2026-06-30 09:00:00+05:30','2026-06-30 09:25:00+05:30',
     'fluoro_normal','orthopedic_fixation',70.00,120.00,18.00,210.00,8.00,22.00,'pass','aligned','intact','compliant','within_limits','2026-06-30 09:40:00+05:30','Ortho hip nailing, low fluoro time'),
    ('AIIMS New Delhi Ansari Nagar','CATH-3','CARM-AIM-041','Philips Allura Xper FD20','55','2026-06-30','2026-06-30 06:30:00+05:30','2026-06-30 07:50:00+05:30',
     'cine','pci_intervention',92.00,500.00,180.00,3200.00,55.00,520.00,'pass','aligned','intact','compliant','exceeds_drl',null,'Long CTO PCI — cumulative skin dose approaching alert threshold'),
    ('AIIMS New Delhi Ansari Nagar','CATH-3','CARM-AIM-041','Philips Allura Xper FD20','56','2026-06-30','2026-06-30 08:10:00+05:30','2026-06-30 09:20:00+05:30',
     'dsa','neuro_intervention',78.00,300.00,40.00,1400.00,48.00,210.00,'pass','aligned','intact','compliant','within_limits','2026-06-30 09:35:00+05:30','Cerebral aneurysm coiling, dose within neuro DRL'),
    ('KIMS Secunderabad','CATH-2','CARM-KIM-017','GE OEC Elite','33','2026-06-29','2026-06-29 07:15:00+05:30','2026-06-29 07:55:00+05:30',
     'fluoro_high','ercp_biliary',85.00,280.00,120.00,1650.00,22.00,180.00,'partial','aligned','intact','pending_renewal','conditional_pass','2026-06-29 08:10:00+05:30','ERCP stone extraction; AERB licence renewal in progress'),
    ('KIMS Secunderabad','CATH-2','CARM-KIM-017','GE OEC Elite','34','2026-06-29','2026-06-29 08:30:00+05:30','2026-06-29 09:05:00+05:30',
     'fluoro_normal','urology_pcnl',72.00,150.00,55.00,890.00,18.00,95.00,'not_checked','not_checked','cracked_major','pending_renewal','service_required',null,'Lead apron major crack found in QA — apron withdrawn from use'),
    ('Care Hospitals Banjara Hills','CATH-1','CARM-CAR-006','Ziehm Vision RFD','9','2026-06-29','2026-06-29 10:00:00+05:30','2026-06-29 10:25:00+05:30',
     'fluoro_low','pain_management',65.00,80.00,8.50,45.00,4.50,6.20,'pass','aligned','intact','compliant','within_limits','2026-06-29 10:40:00+05:30','Guided nerve block, minimal fluoro exposure'),
    ('Yashoda Somajiguda Hyderabad','CATH-4','CARM-YSH-025','Shimadzu Trinias','48','2026-06-28','2026-06-28 06:50:00+05:30','2026-06-28 08:05:00+05:30',
     'cine','cardiac_angiography',88.00,420.00,210.00,4100.00,62.00,640.00,'fail','aligned','cracked_minor','non_compliant','recall_needed',null,'Output drift plus AERB non-compliance — unit recalled for full QA'),
    ('St John''s Bengaluru','CATH-1','CARM-STJ-004','Siemens Cios Alpha','14','2026-06-28','2026-06-28 07:20:00+05:30','2026-06-28 07:45:00+05:30',
     'fluoro_normal','orthopedic_fixation',68.00,110.00,16.00,180.00,7.00,19.00,'pass','aligned','intact','compliant','within_limits','2026-06-28 08:00:00+05:30','Distal radius fixation, routine low-dose fluoro'),
    ('Rainbow Children''s Hyderabad','CATH-2','CARM-RBW-011','Ziehm Vision RFD','27','2026-06-27','2026-06-27 09:15:00+05:30','2026-06-27 09:35:00+05:30',
     'fluoro_low','orthopedic_fixation',60.00,60.00,6.00,30.00,3.50,4.10,'pass','aligned','intact','license_expired','pending_review',null,'Paediatric low-dose case; AERB licence lapsed 3 days ago — flagged')
  ) as q(hosp, lab, tag, model, tn, td, ts, te, mode, proc, kvp, ma, dr, cd, ft, dap, col, laser, apron, aerb, verdict, rel, nt)
  where q.tn ~ '^[0-9]+$';

  -- CAPA seed — attach to specific tests
  insert into public.carm_dose_capa_actions_r3151 (
    dose_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select d.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru',12,'dose_exceeds_drl','tube_aging','replace_xray_tube','2026-07-10',null,'in_progress','patient_dose_alert',850000.00,'X-ray tube output high — replacement quoted by GE'),
    ('Fortis Bannerghatta Bengaluru',13,'collimation_fail','collimator_fault','service_collimator','2026-07-08',null,'escalated','staff_safety_alert',120000.00,'Collimator plus laser aligner service scheduled'),
    ('AIIMS New Delhi Ansari Nagar',55,'dose_exceeds_drl','operator_technique_error','optimize_protocol','2026-07-05','2026-07-02','closed','patient_dose_alert',0.00,'Protocol optimised, pulsed fluoro enabled, operator retrained'),
    ('KIMS Secunderabad',34,'lead_apron_defect','apron_wear','replace_lead_apron','2026-07-06',null,'open','staff_safety_alert',35000.00,'Cracked apron withdrawn, new 0.5mm Pb apron ordered'),
    ('KIMS Secunderabad',33,'aerb_non_compliance','aerb_paperwork_lapse','renew_aerb_license','2026-07-12',null,'in_progress','aerb_notifiable',25000.00,'AERB eLORA renewal filed, awaiting approval'),
    ('Yashoda Somajiguda Hyderabad',48,'output_drift','generator_drift','recalibrate_output','2026-07-04',null,'escalated','aerb_notifiable',180000.00,'Output drift 18 percent — generator recalibration plus AERB report'),
    ('Rainbow Children''s Hyderabad',27,'license_lapse','aerb_paperwork_lapse','renew_aerb_license','2026-06-30',null,'overdue','aerb_notifiable',25000.00,'Licence expired — renewal overdue, unit use restricted')
  ) as q(hosp_key, tn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.carm_dose_r3151 d
    on d.hospital_name = q.hosp_key and d.test_number = q.tn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Dose verdict distribution
create or replace function public.founder_r3151_dose_verdict_rollup()
returns table(dose_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.carm_dose_r3151)
  select l.dose_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.carm_dose_r3151 l
  group by l.dose_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_dose_verdict_rollup() from public, anon;
grant execute on function public.founder_r3151_dose_verdict_rollup() to authenticated;

-- 2) Hospital-level dose compliance scorecard
create or replace function public.founder_r3151_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  within_limits bigint,
  exceeds_drl bigint,
  service_required bigint,
  recalls bigint,
  collimation_fails bigint,
  apron_defects bigint,
  aerb_noncompliant bigint,
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
    count(*) filter (where l.dose_verdict = 'within_limits')::bigint,
    count(*) filter (where l.dose_verdict = 'exceeds_drl')::bigint,
    count(*) filter (where l.dose_verdict = 'service_required')::bigint,
    count(*) filter (where l.dose_verdict = 'recall_needed')::bigint,
    count(*) filter (where l.collimation_check = 'fail')::bigint,
    count(*) filter (where l.lead_apron_check in ('cracked_minor','cracked_major','missing'))::bigint,
    count(*) filter (where l.aerb_compliance in ('non_compliant','license_expired'))::bigint,
    round(100.0 * count(*) filter (where l.dose_verdict in ('within_limits','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.carm_dose_r3151 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3151_hospital_scorecard() to authenticated;

-- 3) Imaging mode × clinical procedure breakdown
create or replace function public.founder_r3151_mode_procedure_matrix()
returns table(
  imaging_mode text,
  clinical_procedure text,
  tests bigint,
  exceeds bigint,
  avg_dose_rate numeric,
  avg_cumulative_dose numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.imaging_mode, l.clinical_procedure, count(*)::bigint,
    count(*) filter (where l.dose_verdict = 'exceeds_drl')::bigint,
    round(avg(l.dose_rate_mgy_min), 2),
    round(avg(l.cumulative_dose_mgy), 2)
  from public.carm_dose_r3151 l
  group by l.imaging_mode, l.clinical_procedure
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_mode_procedure_matrix() from public, anon;
grant execute on function public.founder_r3151_mode_procedure_matrix() to authenticated;

-- 4) Daily dose trend
create or replace function public.founder_r3151_dose_daily_trend()
returns table(
  test_date date,
  tests bigint,
  within_limits bigint,
  exceeds_drl bigint,
  avg_dose_rate numeric,
  avg_dap numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.dose_verdict = 'within_limits')::bigint,
    count(*) filter (where l.dose_verdict = 'exceeds_drl')::bigint,
    round(avg(l.dose_rate_mgy_min), 2),
    round(avg(l.dap_gycm2), 2)
  from public.carm_dose_r3151 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3151_dose_daily_trend() from public, anon;
grant execute on function public.founder_r3151_dose_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3151_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_flag bigint)
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
  from public.carm_dose_capa_actions_r3151 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_capa_status_board() from public, anon;
grant execute on function public.founder_r3151_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3151_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.carm_dose_capa_actions_r3151)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.carm_dose_capa_actions_r3151 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3151_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3151_regulatory_impact_digest()
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
  from public.carm_dose_capa_actions_r3151 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3151_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3151_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority dose queue
create or replace function public.founder_r3151_high_risk_queue()
returns table(
  hospital_name text,
  cath_lab_code text,
  carm_asset_tag text,
  test_date date,
  dose_verdict text,
  imaging_mode text,
  dose_rate_mgy_min numeric,
  cumulative_dose_mgy numeric,
  aerb_compliance text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.cath_lab_code, l.carm_asset_tag, l.test_date,
    l.dose_verdict, l.imaging_mode, l.dose_rate_mgy_min, l.cumulative_dose_mgy, l.aerb_compliance, l.notes
  from public.carm_dose_r3151 l
  where l.dose_verdict in ('exceeds_drl','quarantined','service_required','recall_needed','pending_review','conditional_pass')
     or l.collimation_check = 'fail'
     or l.laser_alignment_check = 'misaligned'
     or l.lead_apron_check in ('cracked_major','missing')
     or l.aerb_compliance in ('non_compliant','license_expired')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3151_high_risk_queue() from public, anon;
grant execute on function public.founder_r3151_high_risk_queue() to authenticated;
