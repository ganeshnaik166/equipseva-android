-- Round 3294: Customer Hospital Surgical Instrument-Tray & Sponge/Needle Count Safety Audit
-- Retained-surgical-item prevention — tray type × count method × sponge/needle reconciliation × tray integrity × documentation × never-event verdict × CAPA

-- =============================================================================
-- TABLE 1: surgical_tray_count_r3294 — per-case tray & count safety audits
-- =============================================================================
create table if not exists public.surgical_tray_count_r3294 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_number text not null,
  case_code text not null,
  tray_type text not null check (tray_type in (
    'major_general','laparoscopy_set','ortho_implant_set','cardiac_set','neuro_set','cs_ob_set'
  )),
  audit_date date not null,
  instrument_count_method text not null check (instrument_count_method in (
    'manual','rfid_assisted','barcode_tray','count_sheet'
  )),
  initial_count_ok boolean not null,
  closing_count_reconciled boolean not null,
  sponge_count_correct boolean not null,
  needle_sharp_count_correct boolean not null,
  count_discrepancy text not null check (count_discrepancy in (
    'none','instrument_missing','sponge_mismatch','needle_mismatch','resolved_by_xray'
  )),
  xray_performed boolean not null,
  tray_integrity_ok boolean not null,
  documentation_complete boolean not null,
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','fail','never_event_flag'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.surgical_tray_count_r3294 enable row level security;

create index if not exists idx_surgical_tray_count_r3294_org on public.surgical_tray_count_r3294(organization_id);
create index if not exists idx_surgical_tray_count_r3294_date on public.surgical_tray_count_r3294(audit_date);
create index if not exists idx_surgical_tray_count_r3294_verdict on public.surgical_tray_count_r3294(audit_verdict);

-- =============================================================================
-- TABLE 2: surgical_tray_count_capa_actions_r3294 — CAPA & never-event actions
-- =============================================================================
create table if not exists public.surgical_tray_count_capa_actions_r3294 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.surgical_tray_count_r3294(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'instrument_miscount','sponge_miscount','needle_miscount','tray_integrity_breach',
    'documentation_gap','retained_item_never_event','count_process_deviation','preventive_audit_due'
  )),
  root_cause text not null check (root_cause in (
    'count_not_performed','staff_distraction','shift_handover_gap','tray_set_incomplete',
    'rfid_tag_failure','documentation_omission','process_noncompliance','pending_investigation','staffing_shortage'
  )),
  corrective_action text not null check (corrective_action in (
    'reeducate_scrub_team','implement_rfid_counting','mandatory_double_count','standardize_count_sheet',
    'xray_before_closure_policy','tray_set_reinventory','update_sop','root_cause_committee_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert','sentinel_event_review'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.surgical_tray_count_capa_actions_r3294 enable row level security;

create index if not exists idx_surgical_tray_capa_r3294_log on public.surgical_tray_count_capa_actions_r3294(audit_log_id);
create index if not exists idx_surgical_tray_capa_r3294_status on public.surgical_tray_count_capa_actions_r3294(capa_status);

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

  -- 14 per-case tray & count audit rows
  insert into public.surgical_tray_count_r3294 (
    organization_id, hospital_name, ot_number, case_code, tray_type,
    audit_date, instrument_count_method,
    initial_count_ok, closing_count_reconciled, sponge_count_correct, needle_sharp_count_correct,
    count_discrepancy, xray_performed, tray_integrity_ok, documentation_complete,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.cc, q.tray,
    q.ad::date, q.icm,
    q.ico, q.ccr, q.scc, q.nsc,
    q.cd, q.xp, q.tio, q.dc,
    q.av, q.nt
  from (values
    ('Apollo Chennai','OT-3','CASE-APL-3301','major_general','2026-07-05','manual',
     true,true,true,true,'none',false,true,true,'pass','Routine count clean — no discrepancy'),
    ('Apollo Chennai','OT-5','CASE-APL-3302','laparoscopy_set','2026-07-05','barcode_tray',
     true,true,true,true,'none',false,true,true,'pass','Lap chole — barcode tray reconciled'),
    ('Fortis Gurgaon','OT-1','CASE-FRT-1201','ortho_implant_set','2026-07-04','count_sheet',
     true,false,true,true,'instrument_missing',true,true,false,'fail','Missing retractor — x-ray done, found in drape fold'),
    ('Fortis Gurgaon','OT-2','CASE-FRT-1202','cardiac_set','2026-07-04','manual',
     true,true,false,true,'sponge_mismatch',true,true,true,'conditional_pass','Sponge count off by one — resolved after full recount'),
    ('Manipal Bengaluru','OT-4','CASE-MNP-4401','neuro_set','2026-07-03','rfid_assisted',
     true,true,true,true,'none',false,true,true,'pass','RFID sponge count auto-reconciled'),
    ('Manipal Bengaluru','OT-6','CASE-MNP-4402','cs_ob_set','2026-07-03','manual',
     true,true,false,false,'needle_mismatch',true,true,true,'conditional_pass','Needle short by one — x-ray negative, documented'),
    ('AIIMS Delhi','OT-7','CASE-AIM-7701','major_general','2026-07-02','count_sheet',
     false,false,false,true,'instrument_missing',true,false,false,'never_event_flag','Retained clamp suspected — never-event review opened'),
    ('AIIMS Delhi','OT-8','CASE-AIM-7702','laparoscopy_set','2026-07-02','manual',
     true,true,true,true,'none',false,true,true,'pass','Clean count, documentation complete'),
    ('CMC Vellore','OT-2','CASE-CMC-2201','ortho_implant_set','2026-07-01','barcode_tray',
     true,true,true,true,'resolved_by_xray',true,true,true,'conditional_pass','Screw count query — x-ray confirmed all accounted'),
    ('CMC Vellore','OT-3','CASE-CMC-2202','cardiac_set','2026-07-01','rfid_assisted',
     true,true,true,true,'none',false,true,true,'pass','Cardiac set RFID reconciled cleanly'),
    ('KIMS Hyderabad','OT-1','CASE-KIM-1101','cs_ob_set','2026-06-30','manual',
     true,false,false,true,'sponge_mismatch',true,false,false,'fail','Sponge count fail at closure — tray integrity breach'),
    ('KIMS Hyderabad','OT-5','CASE-KIM-1102','neuro_set','2026-06-30','count_sheet',
     true,true,true,false,'needle_mismatch',false,true,false,'conditional_pass','Needle mismatch, x-ray declined — documentation gap'),
    ('Medanta Gurugram','OT-3','CASE-MED-3301','major_general','2026-06-29','rfid_assisted',
     true,true,true,true,'none',false,true,true,'pass','Post-SOP-update audit clean'),
    ('Kokilaben Mumbai','OT-9','CASE-KOK-9901','cardiac_set','2026-06-29','manual',
     false,false,true,true,'instrument_missing',true,false,false,'never_event_flag','Retained needle holder — sentinel event review')
  ) as q(hosp, ot, cc, tray, ad, icm, ico, ccr, scc, nsc, cd, xp, tio, dc, av, nt);

  -- CAPA seed — attach to specific audits via case_code
  insert into public.surgical_tray_count_capa_actions_r3294 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CASE-FRT-1201','instrument_miscount','staff_distraction','mandatory_double_count','closed','nabh_finding','2026-07-08','2026-07-05',15000.00,'Retractor found in drape — mandatory double-count instituted'),
    ('CASE-FRT-1202','sponge_miscount','process_noncompliance','standardize_count_sheet','verification_pending','internal_only','2026-07-10',null,8000.00,'Recount resolved; standardized count sheet rolled out'),
    ('CASE-AIM-7701','retained_item_never_event','count_not_performed','root_cause_committee_review','escalated','sentinel_event_review','2026-07-09',null,120000.00,'Never-event committee convened — imaging and re-exploration'),
    ('CASE-KIM-1101','tray_integrity_breach','tray_set_incomplete','tray_set_reinventory','open','iso_13485_deviation','2026-07-12',null,22000.00,'Tray re-inventory ordered — sponge pack count corrected'),
    ('CASE-KIM-1102','documentation_gap','documentation_omission','xray_before_closure_policy','in_progress','cdsco_notifiable','2026-07-11',null,5000.00,'Mandatory x-ray-before-closure policy under rollout'),
    ('CASE-KOK-9901','retained_item_never_event','process_noncompliance','implement_rfid_counting','overdue','patient_safety_alert','2026-07-02',null,150000.00,'RFID counting business case overdue — vendor delay'),
    ('CASE-MNP-4402','needle_miscount','staff_distraction','reeducate_scrub_team','closed','internal_only','2026-07-06','2026-07-05',3000.00,'Scrub team re-education completed and verified')
  ) as q(cc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.surgical_tray_count_r3294 e
    on e.organization_id = v_org_id and e.case_code = q.cc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3294_audit_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgical_tray_count_r3294)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.surgical_tray_count_r3294 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3294_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level count-safety scorecard
create or replace function public.founder_r3294_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  never_events bigint,
  sponge_fail bigint,
  needle_fail bigint,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.audit_verdict = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'never_event_flag')::bigint,
    count(*) filter (where l.sponge_count_correct = false)::bigint,
    count(*) filter (where l.needle_sharp_count_correct = false)::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.surgical_tray_count_r3294 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3294_hospital_scorecard() to authenticated;

-- 3) Tray type × count method matrix
create or replace function public.founder_r3294_tray_method_matrix()
returns table(tray_type text, instrument_count_method text, audits bigint, passed bigint, never_events bigint, discrepancies bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tray_type, l.instrument_count_method, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'never_event_flag')::bigint,
    count(*) filter (where l.count_discrepancy <> 'none')::bigint
  from public.surgical_tray_count_r3294 l
  group by l.tray_type, l.instrument_count_method
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_tray_method_matrix() from public, anon;
grant execute on function public.founder_r3294_tray_method_matrix() to authenticated;

-- 4) Daily count-safety trend
create or replace function public.founder_r3294_daily_count_trend()
returns table(audit_date date, audits bigint, passed bigint, failed bigint, never_events bigint, discrepancies bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'never_event_flag')::bigint,
    count(*) filter (where l.count_discrepancy <> 'none')::bigint
  from public.surgical_tray_count_r3294 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3294_daily_count_trend() from public, anon;
grant execute on function public.founder_r3294_daily_count_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3294_capa_status_board()
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
  from public.surgical_tray_count_capa_actions_r3294 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_capa_status_board() from public, anon;
grant execute on function public.founder_r3294_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3294_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgical_tray_count_capa_actions_r3294)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.surgical_tray_count_capa_actions_r3294 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3294_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3294_regulatory_impact_digest()
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
  from public.surgical_tray_count_capa_actions_r3294 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3294_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3294_regulatory_impact_digest() to authenticated;

-- 8) High-risk count-safety queue (top individual concerns)
create or replace function public.founder_r3294_high_risk_queue()
returns table(
  hospital_name text,
  ot_number text,
  case_code text,
  audit_date date,
  audit_verdict text,
  count_discrepancy text,
  sponge_count_correct boolean,
  needle_sharp_count_correct boolean,
  tray_integrity_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_number, l.case_code, l.audit_date,
    l.audit_verdict, l.count_discrepancy, l.sponge_count_correct,
    l.needle_sharp_count_correct, l.tray_integrity_ok, l.notes
  from public.surgical_tray_count_r3294 l
  where l.audit_verdict in ('conditional_pass','fail','never_event_flag')
     or l.count_discrepancy <> 'none'
     or l.sponge_count_correct = false
     or l.needle_sharp_count_correct = false
     or l.tray_integrity_ok = false
     or l.documentation_complete = false
     or l.closing_count_reconciled = false
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3294_high_risk_queue() from public, anon;
grant execute on function public.founder_r3294_high_risk_queue() to authenticated;
