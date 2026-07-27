-- Round 3508: Engineer Preventive-Maintenance Deferral / Risk-Acceptance Approval Tracker
-- PM deferral / risk-acceptance approval + expiry tracker — engineer × hospital × device × PM type × deferral reason × deferral window × risk level × approval status × approver × CAPA

-- =============================================================================
-- TABLE 1: pm_deferral_risk_r3508 — per-asset PM deferral / risk-acceptance records
-- =============================================================================
create table if not exists public.pm_deferral_risk_r3508 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  deferral_ref text not null,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  asset_tag text not null,
  pm_type text not null check (pm_type in (
    'scheduled_pm','calibration','safety_test','statutory_inspection','oem_service'
  )),
  deferral_reason text not null check (deferral_reason in (
    'parts_unavailable','clinical_priority','budget','access_denied','vendor_delay','staff_shortage'
  )),
  original_due date not null,
  deferred_to date not null,
  deferral_days int not null,
  risk_level text not null check (risk_level in (
    'low','medium','high','critical'
  )),
  approval_status text not null check (approval_status in (
    'pending','approved','rejected','escalated','expired'
  )),
  approver text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_deferral_risk_r3508 enable row level security;

create index if not exists idx_pm_deferral_risk_r3508_org on public.pm_deferral_risk_r3508(organization_id);
create index if not exists idx_pm_deferral_risk_r3508_due on public.pm_deferral_risk_r3508(original_due);
create index if not exists idx_pm_deferral_risk_r3508_status on public.pm_deferral_risk_r3508(approval_status);

-- =============================================================================
-- TABLE 2: pm_deferral_risk_capa_actions_r3508 — CAPA & risk-mitigation actions
-- =============================================================================
create table if not exists public.pm_deferral_risk_capa_actions_r3508 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  deferral_id uuid not null references public.pm_deferral_risk_r3508(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'pm_overdue_high_risk','calibration_deferral_risk','safety_test_lapse',
    'statutory_inspection_overdue','oem_service_backlog','approval_expired',
    'repeated_deferral','critical_asset_downtime_risk'
  )),
  root_cause text not null check (root_cause in (
    'spare_parts_shortage','budget_freeze','vendor_sla_breach','clinical_schedule_conflict',
    'facility_access_restricted','staff_shortage','procurement_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_parts_procurement','escalate_to_management','reschedule_pm_window',
    'engage_oem_service','allocate_budget','assign_backup_engineer',
    'interim_risk_mitigation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_exposure_score numeric(5,2),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_deferral_risk_capa_actions_r3508 enable row level security;

create index if not exists idx_pm_deferral_risk_capa_r3508_link on public.pm_deferral_risk_capa_actions_r3508(deferral_id);
create index if not exists idx_pm_deferral_risk_capa_r3508_status on public.pm_deferral_risk_capa_actions_r3508(capa_status);

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

  -- 16 PM deferral / risk-acceptance rows
  insert into public.pm_deferral_risk_r3508 (
    organization_id, deferral_ref, engineer_name, hospital_name, device_model, asset_tag,
    pm_type, deferral_reason, original_due, deferred_to, deferral_days,
    risk_level, approval_status, approver, notes
  )
  select v_org_id, q.ref, q.eng, q.hosp, q.model, q.asset,
    q.pmtype, q.reason, q.odue::date, q.ddue::date, q.ddays::int,
    q.risk, q.astat, q.appr, q.nt
  from (values
    ('DEF-APL-01','Ravi Kumar','Apollo Chennai','GE Datex-Ohmeda S/5','AST-APL-VENT-01',
     'scheduled_pm','parts_unavailable','2026-06-15','2026-07-30',45,'medium','approved','Biomed HOD','Ventilator PM deferred pending flow sensor'),
    ('DEF-APL-02','Ravi Kumar','Apollo Chennai','Philips IntelliVue MX550','AST-APL-MON-02',
     'calibration','clinical_priority','2026-06-20','2026-07-10',20,'low','approved','Biomed HOD','Monitor cal deferred during peak OT load'),
    ('DEF-FRT-11','Suresh Nair','Fortis Gurgaon','Drager Fabius GS','AST-FRT-ANE-11',
     'safety_test','access_denied','2026-06-10','2026-08-05',56,'high','escalated','Regional Service Mgr','Anesthesia machine safety test blocked — OT access denied'),
    ('DEF-FRT-12','Suresh Nair','Fortis Gurgaon','Siemens Somatom CT','AST-FRT-CT-12',
     'statutory_inspection','vendor_delay','2026-05-30','2026-08-15',77,'critical','escalated','Regional Service Mgr','AERB CT statutory inspection overdue — vendor delay'),
    ('DEF-MNP-21','Anita Rao','Manipal Bengaluru','Mindray BeneVision N22','AST-MNP-MON-21',
     'calibration','budget','2026-06-05','2026-07-20',45,'medium','pending','Biomed Lead','Central monitor cal deferred pending budget approval'),
    ('DEF-MNP-22','Anita Rao','Manipal Bengaluru','GE Vivid E95','AST-MNP-USG-22',
     'scheduled_pm','staff_shortage','2026-06-18','2026-07-05',17,'low','approved','Biomed Lead','Echo PM deferred — biomed staff shortage'),
    ('DEF-AIM-31','Vikram Singh','AIIMS Delhi','Varian TrueBeam LINAC','AST-AIM-LINAC-31',
     'statutory_inspection','vendor_delay','2026-05-20','2026-08-25',97,'critical','expired','Radiation Safety Officer','LINAC AERB inspection deferral approval expired — re-file needed'),
    ('DEF-AIM-32','Vikram Singh','AIIMS Delhi','Maquet Servo-i','AST-AIM-VENT-32',
     'safety_test','parts_unavailable','2026-06-12','2026-07-28',46,'high','approved','Radiation Safety Officer','ICU ventilator electrical safety test deferred — parts'),
    ('DEF-CMC-41','Deepa Menon','CMC Vellore','Roche Cobas 6000','AST-CMC-LAB-41',
     'oem_service','vendor_delay','2026-06-08','2026-07-25',47,'medium','approved','Lab Biomed','Analyzer OEM service deferred — vendor scheduling'),
    ('DEF-CMC-42','Deepa Menon','CMC Vellore','Getinge Autoclave','AST-CMC-CSSD-42',
     'statutory_inspection','access_denied','2026-06-01','2026-08-10',70,'high','rejected','Lab Biomed','Autoclave pressure-vessel inspection deferral rejected — must comply'),
    ('DEF-KIM-51','Rohit Sharma','KIMS Hyderabad','Philips Azurion','AST-KIM-CATH-51',
     'scheduled_pm','clinical_priority','2026-06-22','2026-07-12',20,'medium','approved','Cath Lab Biomed','Cath lab PM deferred during high case volume'),
    ('DEF-KIM-52','Rohit Sharma','KIMS Hyderabad','Fresenius 4008S','AST-KIM-DIAL-52',
     'safety_test','staff_shortage','2026-06-14','2026-07-18',34,'medium','pending','Cath Lab Biomed','Dialysis machine safety test deferred — staff shortage'),
    ('DEF-YSH-61','Meena Iyer','Yashoda Hyderabad','Stryker System 8','AST-YSH-OT-61',
     'calibration','budget','2026-06-25','2026-07-15',20,'low','approved','OT Biomed','Powered drill torque cal deferred — budget cycle'),
    ('DEF-YSH-62','Meena Iyer','Yashoda Hyderabad','Medtronic Bispectral','AST-YSH-OT-62',
     'oem_service','parts_unavailable','2026-06-09','2026-08-01',53,'high','escalated','OT Biomed','Depth monitor OEM service deferred — sensor backorder'),
    ('DEF-KKB-71','Arjun Patel','Kokilaben Mumbai','Siemens Artis Q','AST-KKB-CATH-71',
     'statutory_inspection','vendor_delay','2026-05-25','2026-08-20',87,'critical','pending','Chief Biomed','Angio suite AERB inspection deferral pending — vendor delay'),
    ('DEF-KKB-72','Arjun Patel','Kokilaben Mumbai','Hamilton G5','AST-KKB-ICU-72',
     'scheduled_pm','clinical_priority','2026-06-28','2026-07-08',10,'low','approved','Chief Biomed','ICU ventilator PM deferred short window — clinical priority')
  ) as q(ref, eng, hosp, model, asset, pmtype, reason, odue, ddue, ddays, risk, astat, appr, nt);

  -- CAPA seed — attach to specific deferrals via deferral_ref business key
  insert into public.pm_deferral_risk_capa_actions_r3508 (
    organization_id, deferral_id, finding_category, root_cause, corrective_action,
    capa_status, risk_exposure_score, estimated_cost_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.rexp::numeric, q.cost::numeric, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEF-FRT-12','statutory_inspection_overdue','vendor_sla_breach','engage_oem_service','in_progress',85.0,120000.00,'Suresh Nair','2026-07-20',null,'CT AERB inspection escalated to OEM — interim shielding check done'),
    ('DEF-AIM-31','approval_expired','procurement_delay','escalate_to_management','escalated',95.0,250000.00,'Vikram Singh','2026-07-15',null,'LINAC inspection approval expired — management escalation filed'),
    ('DEF-KKB-71','statutory_inspection_overdue','vendor_sla_breach','engage_oem_service','open',90.0,180000.00,'Arjun Patel','2026-07-25',null,'Angio AERB deferral — awaiting vendor confirmation'),
    ('DEF-FRT-11','safety_test_lapse','facility_access_restricted','reschedule_pm_window','in_progress',70.0,15000.00,'Suresh Nair','2026-07-18',null,'Anesthesia safety test — OT window being coordinated'),
    ('DEF-CMC-42','statutory_inspection_overdue','facility_access_restricted','interim_risk_mitigation','verification_pending',72.0,25000.00,'Deepa Menon','2026-07-16','2026-07-22','Autoclave inspection deferral rejected — compliance rescheduled'),
    ('DEF-YSH-62','oem_service_backlog','spare_parts_shortage','expedite_parts_procurement','open',68.0,42000.00,'Meena Iyer','2026-07-30',null,'Depth monitor sensor backorder — expediting procurement'),
    ('DEF-AIM-32','safety_test_lapse','spare_parts_shortage','expedite_parts_procurement','closed',60.0,8500.00,'Vikram Singh','2026-07-10','2026-07-09','Ventilator safety test parts received — test passed'),
    ('DEF-KIM-52','pm_overdue_high_risk','staff_shortage','assign_backup_engineer','overdue',55.0,5000.00,'Rohit Sharma','2026-07-14',null,'Dialysis safety test — backup engineer assignment pending')
  ) as q(ref, fc, rc, ca, cst, rexp, cost, own, tcd, acd, nt)
  join public.pm_deferral_risk_r3508 e
    on e.organization_id = v_org_id and e.deferral_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Approval-status distribution
create or replace function public.founder_r3508_approval_status_rollup()
returns table(approval_status text, deferrals bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_deferral_risk_r3508)
  select l.approval_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pm_deferral_risk_r3508 l
  group by l.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3508_approval_status_rollup() from public, anon;
grant execute on function public.founder_r3508_approval_status_rollup() to authenticated;

-- 2) PM-type scorecard
create or replace function public.founder_r3508_pm_type_scorecard()
returns table(
  pm_type text,
  total_deferrals bigint,
  approved bigint,
  pending bigint,
  escalated bigint,
  expired bigint,
  rejected bigint,
  high_risk bigint,
  avg_deferral_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pm_type,
    count(*)::bigint,
    count(*) filter (where l.approval_status = 'approved')::bigint,
    count(*) filter (where l.approval_status = 'pending')::bigint,
    count(*) filter (where l.approval_status = 'escalated')::bigint,
    count(*) filter (where l.approval_status = 'expired')::bigint,
    count(*) filter (where l.approval_status = 'rejected')::bigint,
    count(*) filter (where l.risk_level in ('high','critical'))::bigint,
    round(avg(l.deferral_days), 1)
  from public.pm_deferral_risk_r3508 l
  group by l.pm_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3508_pm_type_scorecard() from public, anon;
grant execute on function public.founder_r3508_pm_type_scorecard() to authenticated;

-- 3) Deferral-reason × risk-level matrix
create or replace function public.founder_r3508_reason_risk_matrix()
returns table(deferral_reason text, risk_level text, deferrals bigint, avg_deferral_days numeric, pending_or_escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.deferral_reason, l.risk_level, count(*)::bigint,
    round(avg(l.deferral_days), 1),
    count(*) filter (where l.approval_status in ('pending','escalated'))::bigint
  from public.pm_deferral_risk_r3508 l
  group by l.deferral_reason, l.risk_level
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3508_reason_risk_matrix() from public, anon;
grant execute on function public.founder_r3508_reason_risk_matrix() to authenticated;

-- 4) Monthly deferral trend (by original due month)
create or replace function public.founder_r3508_monthly_deferral_trend()
returns table(deferral_month date, deferrals bigint, avg_deferral_days numeric, high_risk bigint, expired bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.original_due)::date,
    count(*)::bigint,
    round(avg(l.deferral_days), 1),
    count(*) filter (where l.risk_level in ('high','critical'))::bigint,
    count(*) filter (where l.approval_status = 'expired')::bigint
  from public.pm_deferral_risk_r3508 l
  group by date_trunc('month', l.original_due)::date
  order by date_trunc('month', l.original_due)::date desc;
end;
$$;

revoke execute on function public.founder_r3508_monthly_deferral_trend() from public, anon;
grant execute on function public.founder_r3508_monthly_deferral_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3508_capa_status_board()
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
  from public.pm_deferral_risk_capa_actions_r3508 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3508_capa_status_board() from public, anon;
grant execute on function public.founder_r3508_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3508_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_deferral_risk_capa_actions_r3508)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pm_deferral_risk_capa_actions_r3508 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3508_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3508_root_cause_pareto() to authenticated;

-- 7) Risk-exposure impact digest (by finding category)
create or replace function public.founder_r3508_risk_exposure_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_risk_exposure numeric, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','overdue','escalated'))::bigint,
    coalesce(sum(c.risk_exposure_score),0)::numeric,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.pm_deferral_risk_capa_actions_r3508 c
  group by c.finding_category
  order by coalesce(sum(c.risk_exposure_score),0) desc;
end;
$$;

revoke execute on function public.founder_r3508_risk_exposure_digest() from public, anon;
grant execute on function public.founder_r3508_risk_exposure_digest() to authenticated;

-- 8) High-risk deferral queue (critical / expired / escalated / high-risk pending)
create or replace function public.founder_r3508_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  device_model text,
  asset_tag text,
  pm_type text,
  deferral_reason text,
  original_due date,
  deferred_to date,
  deferral_days int,
  risk_level text,
  approval_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.device_model, l.asset_tag, l.pm_type,
    l.deferral_reason, l.original_due, l.deferred_to, l.deferral_days,
    l.risk_level, l.approval_status, l.notes
  from public.pm_deferral_risk_r3508 l
  where l.risk_level in ('high','critical')
     or l.approval_status in ('expired','escalated','rejected')
     or (l.risk_level = 'high' and l.approval_status = 'pending')
  order by
    case l.risk_level when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end,
    l.original_due;
end;
$$;

revoke execute on function public.founder_r3508_high_risk_queue() from public, anon;
grant execute on function public.founder_r3508_high_risk_queue() to authenticated;
