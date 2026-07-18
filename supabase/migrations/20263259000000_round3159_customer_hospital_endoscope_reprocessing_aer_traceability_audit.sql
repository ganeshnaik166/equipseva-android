-- Round 3159: Customer Hospital Endoscope Reprocessing (AER) Cycle & Traceability Audit
-- Endoscope reprocessing log — scope type × procedure × leak test × manual clean × disinfectant (PAA/OPA/glut) × MRC concentration × contact time × cycle result × culture × verdict + CAPA

-- =============================================================================
-- TABLE 1: endoscope_aer_r3159 — individual scope reprocessing cycle runs
-- =============================================================================
create table if not exists public.endoscope_aer_r3159 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  endoscopy_suite_code text not null,
  scope_asset_tag text not null,
  scope_serial text not null,
  scope_type text not null check (scope_type in (
    'gastroscope','colonoscope','duodenoscope','bronchoscope',
    'cystoscope','ureteroscope','sigmoidoscope','echoendoscope'
  )),
  procedure_type text not null check (procedure_type in (
    'egd_gastroscopy','colonoscopy','ercp','bronchoscopy',
    'cystoscopy','ureteroscopy','flexible_sigmoidoscopy','endoscopic_ultrasound'
  )),
  reprocessing_method text not null check (reprocessing_method in (
    'aer_automated','manual_high_level_disinfection','sterrad_plasma','eto_sterilization','double_hld_duodenoscope'
  )),
  aer_model text not null,
  cycle_number int not null,
  cycle_date date not null,
  cycle_started_at timestamptz not null,
  cycle_completed_at timestamptz,
  leak_test_result text not null check (leak_test_result in (
    'pass','fail','minor_leak_detected','not_performed'
  )),
  manual_clean_result text not null check (manual_clean_result in (
    'completed_verified','completed_unverified','incomplete','skipped'
  )),
  disinfectant_type text not null check (disinfectant_type in (
    'peracetic_acid','ortho_phthalaldehyde_opa','glutaraldehyde_2pct','hydrogen_peroxide','electrolyzed_acid_water'
  )),
  mrc_concentration_ppm numeric(7,2),
  mrc_test_result text not null check (mrc_test_result in (
    'pass_above_mec','fail_below_mec','borderline','not_tested'
  )),
  contact_time_min numeric(5,1),
  cycle_result text not null check (cycle_result in (
    'completed_pass','completed_with_deviation','aborted','alarm_fault','incomplete'
  )),
  borescope_inspection text check (borescope_inspection in (
    'clean_no_defect','debris_found','channel_scratches','channel_damage','not_inspected'
  )),
  culture_result text check (culture_result in (
    'no_growth','growth_detected','pending','indeterminate','not_cultured'
  )),
  aer_verdict text not null check (aer_verdict in (
    'released_for_use','quarantined','reprocess_required','recall_needed','pending_review','conditional_release'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.endoscope_aer_r3159 enable row level security;

create index if not exists idx_endoscope_aer_r3159_org on public.endoscope_aer_r3159(organization_id);
create index if not exists idx_endoscope_aer_r3159_date on public.endoscope_aer_r3159(cycle_date);
create index if not exists idx_endoscope_aer_r3159_verdict on public.endoscope_aer_r3159(aer_verdict);

-- =============================================================================
-- TABLE 2: endoscope_aer_capa_actions_r3159 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.endoscope_aer_capa_actions_r3159 (
  id uuid primary key default gen_random_uuid(),
  aer_log_id uuid not null references public.endoscope_aer_r3159(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'leak_test_fail','mrc_below_mec','positive_culture','manual_clean_incomplete',
    'cycle_abort','borescope_defect','contact_time_short','channel_damage','documentation_gap','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'scope_channel_damage','worn_biopsy_valve','aer_pump_degraded','disinfectant_expired',
    'water_quality_poor','dilution_error','operator_skip_step','connector_mismatch','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'send_scope_for_repair','replace_biopsy_valve','replace_disinfectant_batch','recalibrate_aer_dosing',
    'retrain_technician','reprocess_and_reculture','quarantine_and_recall','install_water_filter','none_required','schedule_amc_visit'
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

alter table public.endoscope_aer_capa_actions_r3159 enable row level security;

create index if not exists idx_endoscope_aer_capa_r3159_log on public.endoscope_aer_capa_actions_r3159(aer_log_id);
create index if not exists idx_endoscope_aer_capa_r3159_status on public.endoscope_aer_capa_actions_r3159(capa_status);

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

  -- 14 reprocessing cycle log rows
  insert into public.endoscope_aer_r3159 (
    organization_id, hospital_name, endoscopy_suite_code, scope_asset_tag, scope_serial,
    scope_type, procedure_type, reprocessing_method, aer_model,
    cycle_number, cycle_date, cycle_started_at, cycle_completed_at,
    leak_test_result, manual_clean_result, disinfectant_type, mrc_concentration_ppm, mrc_test_result,
    contact_time_min, cycle_result, borescope_inspection, culture_result, aer_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.suite, q.tag, q.serial,
    q.stype, q.ptype, q.method, q.model,
    q.cn::int, q.cd::date, q.cs::timestamptz, q.cc::timestamptz,
    q.leak, q.mclean, q.disinf, q.mrc, q.mrct,
    q.ct, q.cres, q.bore, q.cult, q.verdict, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ENDO-1','SC-APL-014','OLY-GIF-9014','gastroscope','egd_gastroscopy','aer_automated','Olympus OER-Pro',
     '101','2026-07-16','2026-07-16 08:10:00+05:30','2026-07-16 08:38:00+05:30','pass','completed_verified','ortho_phthalaldehyde_opa',3100.00,'pass_above_mec',5.0,'completed_pass','clean_no_defect','not_cultured','released_for_use','2026-07-16 08:45:00+05:30','Routine morning EGD scope'),
    ('Apollo Hyderabad Jubilee Hills','ENDO-2','SC-APL-022','OLY-CF-9022','colonoscope','colonoscopy','aer_automated','Olympus OER-Pro',
     '102','2026-07-16','2026-07-16 09:05:00+05:30','2026-07-16 09:33:00+05:30','pass','completed_verified','ortho_phthalaldehyde_opa',3050.00,'pass_above_mec',5.0,'completed_pass','clean_no_defect','not_cultured','released_for_use','2026-07-16 09:40:00+05:30','Post-colonoscopy standard OPA cycle'),
    ('Fortis Bannerghatta Bengaluru','ENDO-1','SC-FRT-007','PEN-ED-3490','duodenoscope','ercp','double_hld_duodenoscope','Medivators Advantage Plus',
     '88','2026-07-16','2026-07-16 06:30:00+05:30','2026-07-16 07:20:00+05:30','fail','completed_verified','peracetic_acid',1800.00,'pass_above_mec',12.0,'alarm_fault','channel_damage','growth_detected','recall_needed',null,'Leak test fail + Pseudomonas growth — duodenoscope recalled'),
    ('Fortis Bannerghatta Bengaluru','ENDO-2','SC-FRT-011','OLY-BF-1150','bronchoscope','bronchoscopy','aer_automated','Medivators Advantage Plus',
     '89','2026-07-16','2026-07-16 07:40:00+05:30','2026-07-16 08:05:00+05:30','pass','completed_verified','peracetic_acid',2200.00,'pass_above_mec',10.0,'completed_pass','clean_no_defect','pending','conditional_release',null,'Post-TB bronchoscopy — culture pending, conditional use'),
    ('Manipal Whitefield Bengaluru','ENDO-3','SC-MNP-021','FUJ-EG-5300','echoendoscope','endoscopic_ultrasound','aer_automated','Cantel Medivators DSD-201',
     '55','2026-07-15','2026-07-15 10:15:00+05:30','2026-07-15 10:55:00+05:30','pass','completed_unverified','glutaraldehyde_2pct',12000.00,'fail_below_mec',20.0,'completed_with_deviation','debris_found','indeterminate','quarantined',null,'Glutaraldehyde below MEC — quarantined pending reprocess'),
    ('Manipal Whitefield Bengaluru','ENDO-1','SC-MNP-030','OLY-GIF-6030','gastroscope','egd_gastroscopy','aer_automated','Cantel Medivators DSD-201',
     '56','2026-07-15','2026-07-15 11:20:00+05:30','2026-07-15 12:00:00+05:30','pass','completed_verified','glutaraldehyde_2pct',16500.00,'pass_above_mec',20.0,'completed_pass','clean_no_defect','no_growth','released_for_use','2026-07-15 12:10:00+05:30','Fresh glut batch — concentration verified'),
    ('AIIMS New Delhi Ansari Nagar','ENDO-5','SC-AIM-033','PEN-EC-3800','colonoscope','colonoscopy','aer_automated','Steris Reliance EPS',
     '210','2026-07-15','2026-07-15 06:00:00+05:30','2026-07-15 06:30:00+05:30','pass','completed_verified','peracetic_acid',2300.00,'pass_above_mec',10.0,'completed_pass','clean_no_defect','no_growth','released_for_use','2026-07-15 06:40:00+05:30','Routine surveillance culture negative'),
    ('AIIMS New Delhi Ansari Nagar','ENDO-5','SC-AIM-041','OLY-ENF-4041','cystoscope','cystoscopy','sterrad_plasma','Sterrad NX',
     '211','2026-07-15','2026-07-15 07:10:00+05:30','2026-07-15 07:58:00+05:30','pass','completed_verified','hydrogen_peroxide',null,'not_tested',28.0,'completed_pass','clean_no_defect','not_cultured','released_for_use','2026-07-15 08:05:00+05:30','Flexible cystoscope low-temp plasma sterilization'),
    ('KIMS Secunderabad','ENDO-4','SC-KIM-011','OLY-URF-2011','ureteroscope','ureteroscopy','manual_high_level_disinfection','Manual HLD Station',
     '133','2026-07-14','2026-07-14 09:00:00+05:30','2026-07-14 09:35:00+05:30','minor_leak_detected','completed_verified','ortho_phthalaldehyde_opa',2950.00,'borderline',5.0,'completed_with_deviation','channel_scratches','not_cultured','pending_review',null,'Minor leak + OPA borderline — manual HLD flagged for review'),
    ('KIMS Secunderabad','ENDO-4','SC-KIM-019','OLY-GIF-2019','gastroscope','egd_gastroscopy','aer_automated','Olympus OER-Pro',
     '134','2026-07-14','2026-07-14 10:10:00+05:30','2026-07-14 10:40:00+05:30','not_performed','skipped','ortho_phthalaldehyde_opa',3000.00,'pass_above_mec',5.0,'aborted','not_inspected','not_cultured','reprocess_required',null,'Manual clean skipped — cycle aborted, full reprocess ordered'),
    ('Care Hospitals Banjara Hills','ENDO-2','SC-CAR-005','FUJ-EB-4700','bronchoscope','bronchoscopy','aer_automated','Cantel Medivators DSD-201',
     '77','2026-07-14','2026-07-14 08:30:00+05:30','2026-07-14 09:00:00+05:30','pass','completed_verified','peracetic_acid',2250.00,'pass_above_mec',10.0,'completed_pass','clean_no_defect','no_growth','released_for_use','2026-07-14 09:10:00+05:30','Routine bronchoscope reprocessing verified'),
    ('Yashoda Somajiguda Hyderabad','ENDO-6','SC-YSH-018','PEN-EG-2900','gastroscope','egd_gastroscopy','aer_automated','Medivators Advantage Plus',
     '145','2026-07-13','2026-07-13 07:30:00+05:30','2026-07-13 08:00:00+05:30','pass','completed_verified','peracetic_acid',2100.00,'pass_above_mec',10.0,'completed_pass','clean_no_defect','not_cultured','released_for_use','2026-07-13 08:10:00+05:30','Daily first-run cycle monitored'),
    ('St John''s Bengaluru','ENDO-1','SC-STJ-003','OLY-CF-1003','sigmoidoscope','flexible_sigmoidoscopy','aer_automated','Steris Reliance EPS',
     '62','2026-07-13','2026-07-13 06:50:00+05:30','2026-07-13 07:20:00+05:30','pass','completed_verified','peracetic_acid',2200.00,'pass_above_mec',10.0,'completed_pass','clean_no_defect','no_growth','released_for_use','2026-07-13 07:30:00+05:30','Weekly surveillance culture negative'),
    ('Rainbow Children''s Hyderabad','ENDO-3','SC-RBW-009','OLY-BF-3009','bronchoscope','bronchoscopy','eto_sterilization','3M EtO Sterilizer',
     '24','2026-07-12','2026-07-12 07:00:00+05:30',null,'pass','completed_verified','electrolyzed_acid_water',null,'not_tested',60.0,'incomplete','not_inspected','pending','pending_review',null,'Pediatric bronchoscope EtO cycle interrupted — power dip')
  ) as q(hosp, suite, tag, serial, stype, ptype, method, model, cn, cd, cs, cc, leak, mclean, disinf, mrc, mrct, ct, cres, bore, cult, verdict, rel, nt)
  where q.cn ~ '^[0-9]+$';

  -- CAPA seed — attach to specific cycles by hospital + cycle number
  insert into public.endoscope_aer_capa_actions_r3159 (
    aer_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select c.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 88, 'positive_culture','scope_channel_damage','quarantine_and_recall','2026-07-20',null,'escalated','patient_safety_alert',185000.00,'Duodenoscope recalled — Pseudomonas, sent to Olympus for channel repair'),
    ('Fortis Bannerghatta Bengaluru', 88, 'leak_test_fail','scope_channel_damage','send_scope_for_repair','2026-07-22',null,'in_progress','cdsco_notifiable',185000.00,'Same scope — leak in biopsy channel, CDSCO device event filed'),
    ('Manipal Whitefield Bengaluru',  55, 'mrc_below_mec','dilution_error','replace_disinfectant_batch','2026-07-18','2026-07-16','closed','iso_13485_deviation',8500.00,'Glut auto-dosing miscalibrated — batch replaced, retested pass'),
    ('KIMS Secunderabad',            134, 'manual_clean_incomplete','operator_skip_step','retrain_technician','2026-07-19',null,'open','nabh_finding',3000.00,'Technician skipped bedside precleaning — retraining scheduled'),
    ('KIMS Secunderabad',            133, 'contact_time_short','worn_biopsy_valve','replace_biopsy_valve','2026-07-21',null,'verification_pending','internal_only',4500.00,'OPA borderline + minor leak — biopsy valve worn, replacement ordered'),
    ('Rainbow Children''s Hyderabad',  24, 'cycle_abort','preventive_service_backlog','schedule_amc_visit','2026-07-25',null,'overdue','internal_only',12000.00,'EtO cycle interrupted by power dip — add UPS, PM overdue')
  ) as q(hosp_key, cn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.endoscope_aer_r3159 c
    on c.organization_id = v_org_id and c.hospital_name = q.hosp_key and c.cycle_number = q.cn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) AER verdict distribution
create or replace function public.founder_r3159_verdict_rollup()
returns table(aer_verdict text, cycles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.endoscope_aer_r3159)
  select l.aer_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.endoscope_aer_r3159 l
  group by l.aer_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_verdict_rollup() from public, anon;
grant execute on function public.founder_r3159_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3159_hospital_scorecard()
returns table(
  hospital_name text,
  total_cycles bigint,
  released bigint,
  quarantined bigint,
  recalls bigint,
  leak_fail bigint,
  mrc_fail bigint,
  culture_positive bigint,
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
    count(*) filter (where l.aer_verdict = 'released_for_use')::bigint,
    count(*) filter (where l.aer_verdict = 'quarantined')::bigint,
    count(*) filter (where l.aer_verdict = 'recall_needed')::bigint,
    count(*) filter (where l.leak_test_result in ('fail','minor_leak_detected'))::bigint,
    count(*) filter (where l.mrc_test_result = 'fail_below_mec')::bigint,
    count(*) filter (where l.culture_result = 'growth_detected')::bigint,
    round(100.0 * count(*) filter (where l.aer_verdict = 'released_for_use')::numeric / nullif(count(*),0), 1)
  from public.endoscope_aer_r3159 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3159_hospital_scorecard() to authenticated;

-- 3) Scope-type × procedure breakdown
create or replace function public.founder_r3159_scope_procedure_matrix()
returns table(scope_type text, procedure_type text, cycles bigint, released bigint, avg_contact_time numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scope_type, l.procedure_type, count(*)::bigint,
    count(*) filter (where l.aer_verdict = 'released_for_use')::bigint,
    round(avg(l.contact_time_min), 1)
  from public.endoscope_aer_r3159 l
  group by l.scope_type, l.procedure_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_scope_procedure_matrix() from public, anon;
grant execute on function public.founder_r3159_scope_procedure_matrix() to authenticated;

-- 4) Reprocessing daily trend
create or replace function public.founder_r3159_reprocessing_daily_trend()
returns table(cycle_date date, cycles bigint, leak_fail bigint, mrc_fail bigint, culture_positive bigint, released bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cycle_date,
    count(*)::bigint,
    count(*) filter (where l.leak_test_result in ('fail','minor_leak_detected'))::bigint,
    count(*) filter (where l.mrc_test_result = 'fail_below_mec')::bigint,
    count(*) filter (where l.culture_result = 'growth_detected')::bigint,
    count(*) filter (where l.aer_verdict = 'released_for_use')::bigint
  from public.endoscope_aer_r3159 l
  group by l.cycle_date
  order by l.cycle_date desc;
end;
$$;

revoke execute on function public.founder_r3159_reprocessing_daily_trend() from public, anon;
grant execute on function public.founder_r3159_reprocessing_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3159_capa_status_board()
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
  from public.endoscope_aer_capa_actions_r3159 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_capa_status_board() from public, anon;
grant execute on function public.founder_r3159_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3159_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.endoscope_aer_capa_actions_r3159)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.endoscope_aer_capa_actions_r3159 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3159_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3159_regulatory_impact_digest()
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
  from public.endoscope_aer_capa_actions_r3159 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3159_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3159_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (top individual scope concerns)
create or replace function public.founder_r3159_high_risk_queue()
returns table(
  hospital_name text,
  endoscopy_suite_code text,
  scope_asset_tag text,
  scope_type text,
  cycle_date date,
  aer_verdict text,
  leak_test_result text,
  mrc_test_result text,
  culture_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.endoscopy_suite_code, l.scope_asset_tag, l.scope_type, l.cycle_date,
    l.aer_verdict, l.leak_test_result, l.mrc_test_result, l.culture_result, l.notes
  from public.endoscope_aer_r3159 l
  where l.aer_verdict in ('quarantined','reprocess_required','recall_needed','pending_review','conditional_release')
     or l.culture_result = 'growth_detected'
     or l.leak_test_result in ('fail','minor_leak_detected')
     or l.mrc_test_result = 'fail_below_mec'
  order by l.cycle_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3159_high_risk_queue() from public, anon;
grant execute on function public.founder_r3159_high_risk_queue() to authenticated;
