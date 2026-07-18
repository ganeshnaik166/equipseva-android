-- Round 3163: Customer Hospital CSSD Instrument-Tracking & Tray-Assembly Integrity Audit
-- CSSD tray audit — specialty set × instrument count expected/found × missing/damaged × indicator × wrap integrity × load number × traceability barcode × verdict × CAPA

-- =============================================================================
-- TABLE 1: cssd_tray_r3163 — individual tray-assembly integrity audits
-- =============================================================================
create table if not exists public.cssd_tray_r3163 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  cssd_zone_code text not null,
  tray_barcode text not null,
  tray_name text not null,
  specialty_set text not null check (specialty_set in (
    'general_surgery_major','orthopedic_total_knee','orthopedic_total_hip',
    'laparoscopy_basic','cardiothoracic_open','neurosurgery_craniotomy',
    'ophthalmology_phaco','ent_myringotomy','obgyn_c_section',
    'urology_turp','plastic_surgery_minor','dental_oral_max'
  )),
  tracking_method text not null check (tracking_method in (
    'barcode_scan','rfid_tag','manual_checklist','qr_code'
  )),
  audit_date date not null,
  instruments_expected int not null,
  instruments_found int not null,
  missing_count int not null default 0,
  damaged_count int not null default 0,
  chemical_indicator_result text not null check (chemical_indicator_result in (
    'pass_color_change','fail_no_change','partial_change','not_used'
  )),
  biological_indicator_result text check (biological_indicator_result in (
    'negative','positive','pending','not_run'
  )),
  wrap_integrity text not null check (wrap_integrity in (
    'intact','tear_detected','moisture_breach','seal_broken','expired_wrap','peel_pouch_compromised'
  )),
  load_number text not null,
  assembly_verdict text not null check (assembly_verdict in (
    'released_sterile','quarantined','reassembly_required','rejected_incomplete',
    'pending_verification','recall_issued','conditional_release'
  )),
  cssd_technician_id uuid references public.profiles(id) on delete set null,
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cssd_tray_r3163 enable row level security;

create index if not exists idx_cssd_tray_r3163_org on public.cssd_tray_r3163(organization_id);
create index if not exists idx_cssd_tray_r3163_date on public.cssd_tray_r3163(audit_date);
create index if not exists idx_cssd_tray_r3163_verdict on public.cssd_tray_r3163(assembly_verdict);

-- =============================================================================
-- TABLE 2: cssd_tray_capa_actions_r3163 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cssd_tray_capa_actions_r3163 (
  id uuid primary key default gen_random_uuid(),
  tray_audit_id uuid not null references public.cssd_tray_r3163(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_instrument','damaged_instrument','indicator_failure','wrap_breach',
    'count_mismatch','wrong_set_assembled','expired_sterilization','traceability_gap',
    'load_documentation_error','preventive_audit_due'
  )),
  root_cause text not null check (root_cause in (
    'instrument_lost_in_or','staff_count_error','worn_instrument','packaging_defect',
    'sterilizer_malfunction','inventory_shortage','barcode_unreadable','training_gap',
    'rushed_turnaround','pending_investigation','preventive_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_instrument','reassemble_tray','requarantine_set','retrain_staff',
    'reorder_inventory','reprint_barcode_label','recalibrate_scanner','trigger_recall',
    'schedule_amc_visit','none_required','update_count_sheet'
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

alter table public.cssd_tray_capa_actions_r3163 enable row level security;

create index if not exists idx_cssd_tray_capa_r3163_audit on public.cssd_tray_capa_actions_r3163(tray_audit_id);
create index if not exists idx_cssd_tray_capa_r3163_status on public.cssd_tray_capa_actions_r3163(capa_status);

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

  -- 14 tray-assembly audit rows
  insert into public.cssd_tray_r3163 (
    organization_id, hospital_name, cssd_zone_code, tray_barcode, tray_name,
    specialty_set, tracking_method, audit_date,
    instruments_expected, instruments_found, missing_count, damaged_count,
    chemical_indicator_result, biological_indicator_result, wrap_integrity, load_number,
    assembly_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.zone, q.bc, q.tray,
    q.spec, q.tm, q.ad::date,
    q.exp, q.fnd, q.miss, q.dmg,
    q.ci, q.bi, q.wrap, q.load,
    q.verd, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CSSD-A','TRB-APL-0141','General Surgery Major Set',
     'general_surgery_major','barcode_scan','2026-07-16',68,68,0,0,
     'pass_color_change','negative','intact','LOT-APL-2207-01','released_sterile','2026-07-16 07:30:00+05:30','Routine major set — full barcode trace, all counts matched'),
    ('Apollo Hyderabad Jubilee Hills','CSSD-A','TRB-APL-0142','Total Knee Arthroplasty Set',
     'orthopedic_total_knee','barcode_scan','2026-07-16',94,92,2,0,
     'pass_color_change','negative','intact','LOT-APL-2207-02','quarantined',null,'2 Hohmann retractors missing — count mismatch at assembly'),
    ('Fortis Bannerghatta Bengaluru','CSSD-B','TRB-FRT-0071','Laparoscopy Basic Set',
     'laparoscopy_basic','rfid_tag','2026-07-15',42,42,0,1,
     'partial_change','negative','tear_detected','LOT-FRT-2207-11','reassembly_required',null,'Wrap tear plus CI partial — reassemble and re-sterilize'),
    ('Fortis Bannerghatta Bengaluru','CSSD-B','TRB-FRT-0072','Craniotomy Set',
     'neurosurgery_craniotomy','barcode_scan','2026-07-15',120,118,2,1,
     'fail_no_change','positive','moisture_breach','LOT-FRT-2207-12','recall_issued',null,'BI positive and moisture breach — recall issued for load'),
    ('Manipal Whitefield Bengaluru','CSSD-C','TRB-MNP-0211','Total Hip Arthroplasty Set',
     'orthopedic_total_hip','barcode_scan','2026-07-15',88,88,0,0,
     'pass_color_change','negative','intact','LOT-MNP-2207-05','released_sterile','2026-07-15 09:10:00+05:30','Routine — full trace via barcode, released'),
    ('Manipal Whitefield Bengaluru','CSSD-C','TRB-MNP-0212','Phaco Ophthalmology Set',
     'ophthalmology_phaco','manual_checklist','2026-07-14',24,23,1,0,
     'pass_color_change','negative','peel_pouch_compromised','LOT-MNP-2207-06','quarantined',null,'Peel pouch seal compromised — one micro-forcep missing'),
    ('AIIMS New Delhi Ansari Nagar','CSSD-D','TRB-AIM-0331','Open Cardiothoracic Set',
     'cardiothoracic_open','rfid_tag','2026-07-14',156,156,0,0,
     'pass_color_change','negative','intact','LOT-AIM-2207-21','released_sterile','2026-07-14 08:05:00+05:30','RFID full traceability confirmed for open-heart set'),
    ('AIIMS New Delhi Ansari Nagar','CSSD-D','TRB-AIM-0332','C-Section Set',
     'obgyn_c_section','barcode_scan','2026-07-14',46,45,1,0,
     'partial_change','pending','expired_wrap','LOT-AIM-2207-22','conditional_release','2026-07-14 10:20:00+05:30','Wrap near expiry — conditional release with re-wrap flag'),
    ('KIMS Secunderabad','CSSD-E','TRB-KIM-0111','TURP Urology Set',
     'urology_turp','barcode_scan','2026-07-13',38,37,1,1,
     'fail_no_change','not_run','seal_broken','LOT-KIM-2207-31','rejected_incomplete',null,'CI fail and seal broken — rejected, full reprocess'),
    ('KIMS Secunderabad','CSSD-E','TRB-KIM-0112','ENT Myringotomy Set',
     'ent_myringotomy','manual_checklist','2026-07-13',28,28,0,0,
     'pass_color_change','negative','intact','LOT-KIM-2207-32','released_sterile','2026-07-13 06:40:00+05:30','Small set — manual count verified twice'),
    ('Care Hospitals Banjara Hills','CSSD-F','TRB-CAR-0051','Plastic Surgery Minor Set',
     'plastic_surgery_minor','barcode_scan','2026-07-13',52,52,0,2,
     'pass_color_change','negative','intact','LOT-CAR-2207-41','reassembly_required',null,'2 needle holders with worn jaws — swap before release'),
    ('Yashoda Somajiguda Hyderabad','CSSD-G','TRB-YSH-0181','Dental Oral-Max Set',
     'dental_oral_max','qr_code','2026-07-12',34,34,0,0,
     'pass_color_change','negative','intact','LOT-YSH-2207-51','released_sterile','2026-07-12 07:15:00+05:30','QR-coded tray — daily monitored, released'),
    ('St John''s Bengaluru','CSSD-H','TRB-STJ-0031','General Surgery Major Set',
     'general_surgery_major','barcode_scan','2026-07-12',68,66,2,0,
     'not_used','not_run','intact','LOT-STJ-2207-61','pending_verification',null,'CI not used this run — pending verification, 2 items short'),
    ('Rainbow Children''s Hyderabad','CSSD-I','TRB-RBW-0091','Pediatric Laparoscopy Basic Set',
     'laparoscopy_basic','manual_checklist','2026-07-11',40,40,0,1,
     'pass_color_change','negative','tear_detected','LOT-RBW-2207-71','reassembly_required',null,'Minor wrap tear found pre-use — rewrap required')
  ) as q(hosp, zone, bc, tray, spec, tm, ad, exp, fnd, miss, dmg, ci, bi, wrap, load, verd, rel, nt);

  -- CAPA seed — attach to specific trays via barcode tag
  insert into public.cssd_tray_capa_actions_r3163 (
    tray_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('TRB-APL-0142','missing_instrument','staff_count_error','reassemble_tray','2026-07-20',null,'in_progress','nabh_finding',3500.00,'2 Hohmann retractors traced to OR-4, tray held'),
    ('TRB-FRT-0072','indicator_failure','sterilizer_malfunction','trigger_recall','2026-07-18',null,'escalated','patient_safety_alert',62000.00,'BI positive — sterilizer 3 down, batch recalled'),
    ('TRB-MNP-0212','wrap_breach','packaging_defect','requarantine_set','2026-07-17','2026-07-16','closed','iso_13485_deviation',1800.00,'Peel pouch supplier lot rejected, replaced'),
    ('TRB-KIM-0111','indicator_failure','packaging_defect','reassemble_tray','2026-07-19',null,'verification_pending','nabh_finding',4200.00,'Seal integrity checked on all TURP trays'),
    ('TRB-STJ-0031','count_mismatch','staff_count_error','retrain_staff','2026-07-16','2026-07-15','closed','internal_only',0.00,'Count-sheet retraining completed for evening shift'),
    ('TRB-CAR-0051','damaged_instrument','worn_instrument','replace_instrument','2026-07-21',null,'open','iso_13485_deviation',9500.00,'Two needle holders sent for replacement'),
    ('TRB-RBW-0091','wrap_breach','rushed_turnaround','reassemble_tray','2026-07-14',null,'overdue','nabh_finding',2200.00,'Rewrap overdue 3 days — pediatric OT waiting')
  ) as q(bc_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.cssd_tray_r3163 e
    on e.organization_id = v_org_id and e.tray_barcode = q.bc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Assembly verdict distribution
create or replace function public.founder_r3163_verdict_rollup()
returns table(assembly_verdict text, trays bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cssd_tray_r3163)
  select l.assembly_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cssd_tray_r3163 l
  group by l.assembly_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_verdict_rollup() from public, anon;
grant execute on function public.founder_r3163_verdict_rollup() to authenticated;

-- 2) Hospital-level integrity scorecard
create or replace function public.founder_r3163_hospital_scorecard()
returns table(
  hospital_name text,
  total_trays bigint,
  released bigint,
  quarantined bigint,
  recalls bigint,
  missing_total bigint,
  damaged_total bigint,
  integrity_pct numeric
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
    count(*) filter (where l.assembly_verdict = 'released_sterile')::bigint,
    count(*) filter (where l.assembly_verdict = 'quarantined')::bigint,
    count(*) filter (where l.assembly_verdict in ('recall_issued','rejected_incomplete'))::bigint,
    coalesce(sum(l.missing_count),0)::bigint,
    coalesce(sum(l.damaged_count),0)::bigint,
    round(100.0 * count(*) filter (where l.assembly_verdict = 'released_sterile')::numeric / nullif(count(*),0), 1)
  from public.cssd_tray_r3163 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3163_hospital_scorecard() to authenticated;

-- 3) Specialty set × chemical-indicator integrity matrix
create or replace function public.founder_r3163_specialty_integrity_matrix()
returns table(specialty_set text, chemical_indicator_result text, trays bigint, released bigint, avg_instruments numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.specialty_set, l.chemical_indicator_result, count(*)::bigint,
    count(*) filter (where l.assembly_verdict in ('released_sterile','conditional_release'))::bigint,
    round(avg(l.instruments_expected), 1)
  from public.cssd_tray_r3163 l
  group by l.specialty_set, l.chemical_indicator_result
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_specialty_integrity_matrix() from public, anon;
grant execute on function public.founder_r3163_specialty_integrity_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3163_audit_daily_trend()
returns table(audit_date date, trays bigint, released bigint, quarantined bigint, missing_total bigint, damaged_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.assembly_verdict = 'released_sterile')::bigint,
    count(*) filter (where l.assembly_verdict = 'quarantined')::bigint,
    coalesce(sum(l.missing_count),0)::bigint,
    coalesce(sum(l.damaged_count),0)::bigint
  from public.cssd_tray_r3163 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3163_audit_daily_trend() from public, anon;
grant execute on function public.founder_r3163_audit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3163_capa_status_board()
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
  from public.cssd_tray_capa_actions_r3163 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_capa_status_board() from public, anon;
grant execute on function public.founder_r3163_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3163_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cssd_tray_capa_actions_r3163)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cssd_tray_capa_actions_r3163 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3163_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3163_regulatory_impact_digest()
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
  from public.cssd_tray_capa_actions_r3163 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3163_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3163_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority trays queue
create or replace function public.founder_r3163_high_risk_trays()
returns table(
  hospital_name text,
  cssd_zone_code text,
  tray_barcode text,
  tray_name text,
  audit_date date,
  assembly_verdict text,
  chemical_indicator_result text,
  wrap_integrity text,
  missing_count int,
  damaged_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.cssd_zone_code, l.tray_barcode, l.tray_name, l.audit_date,
    l.assembly_verdict, l.chemical_indicator_result, l.wrap_integrity, l.missing_count, l.damaged_count, l.notes
  from public.cssd_tray_r3163 l
  where l.assembly_verdict in ('quarantined','rejected_incomplete','recall_issued','pending_verification','reassembly_required','conditional_release')
     or l.biological_indicator_result = 'positive'
     or l.chemical_indicator_result = 'fail_no_change'
     or l.wrap_integrity in ('tear_detected','moisture_breach','seal_broken','expired_wrap','peel_pouch_compromised')
     or l.missing_count > 0
     or l.damaged_count > 0
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3163_high_risk_trays() from public, anon;
grant execute on function public.founder_r3163_high_risk_trays() to authenticated;
