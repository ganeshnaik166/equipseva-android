-- Round 3380: Engineer Digital Work-Order e-Signature & Proof-of-Service Completion-Integrity Tracker
-- Field-ops WO integrity — service type × work-order status × e-signature × GPS/timestamp × evidence photos × parts/labour × checklist × offline-sync × dispute defensibility × CAPA

-- =============================================================================
-- TABLE 1: wo_esign_r3380 — per work-order proof-of-service completeness audits
-- =============================================================================
create table if not exists public.wo_esign_r3380 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  hospital_name text not null,
  work_order_code text not null,
  service_type text not null check (service_type in (
    'breakdown_repair','preventive_maintenance','installation','calibration','amc_visit','warranty'
  )),
  completed_date date not null,
  work_order_status text not null check (work_order_status in (
    'draft','completed_signed','completed_unsigned','rejected','pending_sync'
  )),
  customer_esignature_captured boolean not null,
  signatory_name_designation_ok boolean not null,
  gps_timestamp_captured boolean not null,
  before_after_photos_count int not null,
  parts_labour_logged boolean not null,
  checklist_attached boolean not null,
  offline_synced boolean not null,
  sync_delay_hours numeric(6,2),
  dispute_defensible boolean not null,
  integrity_verdict text not null check (integrity_verdict in (
    'complete_defensible','minor_gap','unsigned_billing_risk','evidence_missing','sync_pending','rejected_rework'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wo_esign_r3380 enable row level security;

create index if not exists idx_wo_esign_r3380_org on public.wo_esign_r3380(organization_id);
create index if not exists idx_wo_esign_r3380_date on public.wo_esign_r3380(completed_date);
create index if not exists idx_wo_esign_r3380_verdict on public.wo_esign_r3380(integrity_verdict);

-- =============================================================================
-- TABLE 2: wo_esign_capa_actions_r3380 — completion / sync / evidence CAPA actions
-- =============================================================================
create table if not exists public.wo_esign_capa_actions_r3380 (
  id uuid primary key default gen_random_uuid(),
  wo_log_id uuid not null references public.wo_esign_r3380(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_esignature','signatory_details_incomplete','gps_timestamp_missing','insufficient_photos',
    'parts_labour_not_logged','checklist_missing','offline_sync_delay','work_order_rejected','preventive_documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'app_offline_no_signature_capture','engineer_skipped_signature_step','customer_unavailable_at_closeout',
    'device_gps_disabled','poor_network_sync_failure','app_crash_data_loss','training_gap',
    'deliberate_shortcut','pending_investigation','process_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_engineer_on_esign_flow','revisit_site_for_signature','enable_mandatory_gps_capture','enforce_photo_minimum',
    'backfill_parts_labour_log','attach_missing_checklist','force_sync_before_closeout','reject_and_rework_order',
    'escalate_to_ops_manager','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  billing_risk text not null check (billing_risk in (
    'billing_blocked','billing_at_risk','dispute_exposure','revenue_leakage','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wo_esign_capa_actions_r3380 enable row level security;

create index if not exists idx_wo_esign_capa_r3380_log on public.wo_esign_capa_actions_r3380(wo_log_id);
create index if not exists idx_wo_esign_capa_r3380_status on public.wo_esign_capa_actions_r3380(capa_status);

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

  -- 14 work-order integrity rows
  insert into public.wo_esign_r3380 (
    organization_id, engineer_name, region, hospital_name, work_order_code, service_type,
    completed_date, work_order_status, customer_esignature_captured, signatory_name_designation_ok, gps_timestamp_captured,
    before_after_photos_count, parts_labour_logged, checklist_attached, offline_synced, sync_delay_hours,
    dispute_defensible, integrity_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.hosp, q.woc, q.st,
    q.cd::date, q.wos, q.esign, q.sig, q.gps,
    q.photos, q.parts, q.chk, q.sync, q.delay,
    q.disp, q.iv, q.nt
  from (values
    ('Rajesh Kumar','South','Apollo Chennai Greams Road','WO-APL-4401','breakdown_repair','2026-07-10','completed_signed',true,true,true,6,true,true,true,1.20,true,'complete_defensible','Signed by Dr. Menon (Biomedical HOD); GPS and timestamp captured; 6 before/after photos'),
    ('Priya Nair','South','Manipal Bengaluru Old Airport Road','WO-MNP-4402','preventive_maintenance','2026-07-10','completed_signed',true,true,true,4,true,true,true,0.50,true,'complete_defensible','PM checklist attached and e-signature captured on device at closeout'),
    ('Arjun Reddy','South','KIMS Hyderabad Kondapur','WO-KIM-4403','amc_visit','2026-07-09','completed_unsigned',false,false,true,3,true,true,true,2.00,false,'unsigned_billing_risk','Signatory left before closeout; no e-signature captured; billing on hold'),
    ('Vikram Singh','North','Fortis Gurgaon Sector 44','WO-FRT-4404','installation','2026-07-09','completed_signed',true,true,true,8,true,true,true,3.50,true,'complete_defensible','New CT install signed by radiology head; full evidence set attached'),
    ('Deepak Sharma','North','AIIMS Delhi Ansari Nagar','WO-AIM-4405','calibration','2026-07-08','completed_signed',true,true,false,5,true,true,true,1.00,true,'minor_gap','GPS not captured inside shielded room; otherwise signed and complete'),
    ('Suresh Iyer','South','CMC Vellore','WO-CMC-4406','breakdown_repair','2026-07-08','completed_unsigned',false,true,true,2,true,false,true,4.00,false,'evidence_missing','No e-signature and checklist not attached; evidence set incomplete'),
    ('Kavya Menon','South','Narayana Health Bengaluru','WO-NAR-4407','preventive_maintenance','2026-07-07','pending_sync',true,true,true,4,true,true,false,26.50,true,'sync_pending','Basement dead-zone; work order unsynced 26h; e-signature held on device'),
    ('Anil Gupta','North','Fortis Gurgaon Sector 44','WO-FRT-4408','warranty','2026-07-07','rejected',false,false,false,0,false,false,true,5.00,false,'rejected_rework','Rejected by ops: no signature, no photos, no checklist; full rework required'),
    ('Manish Patel','West','Kokilaben Mumbai Andheri','WO-KOK-4409','amc_visit','2026-07-06','completed_signed',true,true,true,5,true,true,true,0.80,true,'complete_defensible','AMC quarterly visit fully documented, signed and synced within SLA'),
    ('Ramesh Rao','South','Care Hospitals Hyderabad Banjara Hills','WO-CAR-4410','calibration','2026-07-06','completed_signed',true,false,true,4,true,true,true,1.50,false,'minor_gap','Signatory name captured but designation missing; verify before billing'),
    ('Priya Nair','South','Yashoda Hyderabad Somajiguda','WO-YSH-4411','breakdown_repair','2026-07-05','pending_sync',true,true,true,3,true,true,false,18.00,true,'sync_pending','Poor network at site; sync delayed 18h; evidence intact once uploaded'),
    ('Vikram Singh','North','Fortis Gurgaon Sector 44','WO-FRT-4412','preventive_maintenance','2026-07-05','completed_unsigned',false,false,true,1,false,true,true,3.00,false,'unsigned_billing_risk','Rushed closeout: no e-signature, parts/labour not logged; billing blocked'),
    ('Deepak Sharma','North','AIIMS Delhi Ansari Nagar','WO-AIM-4413','installation','2026-07-04','draft',false,false,false,2,false,false,false,null,false,'evidence_missing','Draft abandoned mid-visit after app crash; minimal evidence; revisit needed'),
    ('Ramesh Rao','South','KIMS Hyderabad Kondapur','WO-KIM-4414','warranty','2026-07-04','completed_signed',true,true,true,6,true,true,true,0.60,true,'complete_defensible','Warranty visit signed with GPS, timestamp and complete before/after photos')
  ) as q(eng, reg, hosp, woc, st, cd, wos, esign, sig, gps, photos, parts, chk, sync, delay, disp, iv, nt);

  -- CAPA seed — attach to specific work orders via work_order_code
  insert into public.wo_esign_capa_actions_r3380 (
    wo_log_id, finding_category, root_cause, corrective_action,
    capa_status, billing_risk, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.br, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WO-KIM-4403','missing_esignature','customer_unavailable_at_closeout','revisit_site_for_signature','in_progress','billing_at_risk','2026-07-14',null,3500.00,'Return visit scheduled to capture signatory e-signature for AMC billing'),
    ('WO-CMC-4406','checklist_missing','training_gap','retrain_engineer_on_esign_flow','open','dispute_exposure','2026-07-16',null,2000.00,'Engineer retraining on evidence-capture SOP; checklist to be backfilled'),
    ('WO-NAR-4407','offline_sync_delay','poor_network_sync_failure','force_sync_before_closeout','verification_pending','none','2026-07-12',null,0.00,'Work order synced after 26h; verifying integrity before billing release'),
    ('WO-FRT-4408','work_order_rejected','deliberate_shortcut','reject_and_rework_order','escalated','billing_blocked','2026-07-11',null,6500.00,'Full rework ordered; escalated to ops manager over repeat closeout shortcuts'),
    ('WO-FRT-4412','parts_labour_not_logged','engineer_skipped_signature_step','backfill_parts_labour_log','open','billing_blocked','2026-07-13',null,4200.00,'Parts/labour and e-signature missing; billing blocked pending backfill'),
    ('WO-AIM-4413','insufficient_photos','app_crash_data_loss','enforce_photo_minimum','overdue','revenue_leakage','2026-07-09',null,1500.00,'Draft abandoned after app crash; revisit overdue; revenue leakage risk'),
    ('WO-YSH-4411','offline_sync_delay','poor_network_sync_failure','enable_mandatory_gps_capture','closed','none','2026-07-08','2026-07-09',0.00,'Synced within SLA after 18h; evidence intact; closed at no cost')
  ) as q(woc, fc, rc, ca, cst, br, tcd, acd, cost, nt)
  join public.wo_esign_r3380 e
    on e.organization_id = v_org_id and e.work_order_code = q.woc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Integrity verdict distribution
create or replace function public.founder_r3380_integrity_verdict_rollup()
returns table(integrity_verdict text, work_orders bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wo_esign_r3380)
  select l.integrity_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.wo_esign_r3380 l
  group by l.integrity_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_integrity_verdict_rollup() from public, anon;
grant execute on function public.founder_r3380_integrity_verdict_rollup() to authenticated;

-- 2) Engineer-level proof-of-service scorecard
create or replace function public.founder_r3380_engineer_scorecard()
returns table(
  engineer_name text,
  total_orders bigint,
  signed_complete bigint,
  unsigned_risk bigint,
  rejected bigint,
  esign_missing bigint,
  gps_missing bigint,
  sync_pending bigint,
  defensible_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.work_order_status = 'completed_signed')::bigint,
    count(*) filter (where l.integrity_verdict in ('unsigned_billing_risk','evidence_missing'))::bigint,
    count(*) filter (where l.work_order_status = 'rejected')::bigint,
    count(*) filter (where not l.customer_esignature_captured)::bigint,
    count(*) filter (where not l.gps_timestamp_captured)::bigint,
    count(*) filter (where l.work_order_status = 'pending_sync' or not l.offline_synced)::bigint,
    round(100.0 * count(*) filter (where l.dispute_defensible)::numeric / nullif(count(*),0), 1)
  from public.wo_esign_r3380 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3380_engineer_scorecard() to authenticated;

-- 3) Service-type × work-order-status matrix
create or replace function public.founder_r3380_service_status_matrix()
returns table(service_type text, work_order_status text, work_orders bigint, defensible bigint, avg_photos numeric, avg_sync_delay_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_type, l.work_order_status, count(*)::bigint,
    count(*) filter (where l.dispute_defensible)::bigint,
    round(avg(l.before_after_photos_count), 1),
    round(avg(l.sync_delay_hours), 1)
  from public.wo_esign_r3380 l
  group by l.service_type, l.work_order_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_service_status_matrix() from public, anon;
grant execute on function public.founder_r3380_service_status_matrix() to authenticated;

-- 4) Daily completion / integrity trend
create or replace function public.founder_r3380_daily_completion_trend()
returns table(completed_date date, work_orders bigint, signed bigint, unsigned bigint, esign_missing bigint, sync_pending bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.completed_date,
    count(*)::bigint,
    count(*) filter (where l.work_order_status = 'completed_signed')::bigint,
    count(*) filter (where l.work_order_status = 'completed_unsigned')::bigint,
    count(*) filter (where not l.customer_esignature_captured)::bigint,
    count(*) filter (where l.work_order_status = 'pending_sync')::bigint
  from public.wo_esign_r3380 l
  group by l.completed_date
  order by l.completed_date desc;
end;
$$;

revoke execute on function public.founder_r3380_daily_completion_trend() from public, anon;
grant execute on function public.founder_r3380_daily_completion_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3380_capa_status_board()
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
  from public.wo_esign_capa_actions_r3380 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_capa_status_board() from public, anon;
grant execute on function public.founder_r3380_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3380_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wo_esign_capa_actions_r3380)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.wo_esign_capa_actions_r3380 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3380_root_cause_pareto() to authenticated;

-- 7) Billing / dispute-risk digest
create or replace function public.founder_r3380_billing_risk_digest()
returns table(billing_risk text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.billing_risk, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.wo_esign_capa_actions_r3380 c
  group by c.billing_risk
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3380_billing_risk_digest() from public, anon;
grant execute on function public.founder_r3380_billing_risk_digest() to authenticated;

-- 8) High-risk work-order queue (top individual concerns)
create or replace function public.founder_r3380_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  hospital_name text,
  work_order_code text,
  completed_date date,
  service_type text,
  work_order_status text,
  integrity_verdict text,
  before_after_photos_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.hospital_name, l.work_order_code, l.completed_date,
    l.service_type, l.work_order_status, l.integrity_verdict, l.before_after_photos_count, l.notes
  from public.wo_esign_r3380 l
  where l.integrity_verdict in ('unsigned_billing_risk','evidence_missing','sync_pending','rejected_rework','minor_gap')
     or l.work_order_status in ('completed_unsigned','rejected','pending_sync','draft')
     or not l.customer_esignature_captured
     or not l.gps_timestamp_captured
     or not l.offline_synced
     or not l.dispute_defensible
  order by l.completed_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3380_high_risk_queue() from public, anon;
grant execute on function public.founder_r3380_high_risk_queue() to authenticated;
