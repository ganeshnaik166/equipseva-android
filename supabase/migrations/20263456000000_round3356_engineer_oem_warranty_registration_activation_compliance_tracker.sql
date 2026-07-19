-- Round 3356: Engineer OEM Warranty Registration & Activation Compliance Tracker
-- Install-time warranty compliance — equipment type × OEM vendor × registration window × activation × blocking reason × verdict × CAPA
-- Missed OEM registration within the window voids coverage and creates financial exposure.

-- =============================================================================
-- TABLE 1: oem_warranty_reg_r3356 — per-install registration/activation compliance
-- =============================================================================
create table if not exists public.oem_warranty_reg_r3356 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  install_code text not null,
  equipment_type text not null check (equipment_type in (
    'imaging','patient_monitoring','dialysis','ventilator','lab_analyzer','infusion_pump'
  )),
  oem_vendor text not null check (oem_vendor in (
    'ge_healthcare','philips','siemens_healthineers','mindray','fresenius_medical','baxter',
    'nihon_kohden','draeger','roche_diagnostics','bpl_medical','hamilton_medical','nipro'
  )),
  serial_number text not null,
  install_date date not null,
  warranty_months int not null,
  registration_deadline date not null,
  registration_submitted boolean not null,
  registration_date date,
  oem_activation_confirmed boolean not null,
  warranty_start_date date,
  warranty_end_date date,
  days_to_deadline int not null,
  blocking_reason text not null check (blocking_reason in (
    'none','missing_docs','customer_info_pending','portal_error','engineer_delay'
  )),
  registration_verdict text not null check (registration_verdict in (
    'activated','pending_in_window','overdue_at_risk','lapsed_void','activated_late'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_warranty_reg_r3356 enable row level security;

create index if not exists idx_oem_warranty_reg_r3356_org on public.oem_warranty_reg_r3356(organization_id);
create index if not exists idx_oem_warranty_reg_r3356_date on public.oem_warranty_reg_r3356(install_date);
create index if not exists idx_oem_warranty_reg_r3356_verdict on public.oem_warranty_reg_r3356(registration_verdict);

-- =============================================================================
-- TABLE 2: oem_warranty_reg_capa_actions_r3356 — expedite/escalation CAPA actions
-- =============================================================================
create table if not exists public.oem_warranty_reg_capa_actions_r3356 (
  id uuid primary key default gen_random_uuid(),
  reg_log_id uuid not null references public.oem_warranty_reg_r3356(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'registration_overdue','activation_not_confirmed','missing_documentation','portal_submission_error',
    'customer_info_gap','warranty_lapsed','deadline_at_risk','serial_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'engineer_scheduling_delay','customer_docs_pending','oem_portal_downtime','wrong_serial_captured',
    'install_paperwork_incomplete','vendor_activation_backlog','pending_investigation','process_handoff_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_portal_submission','escalate_to_oem_account_manager','collect_customer_documents','correct_serial_record',
    'resubmit_registration','request_backdated_activation','assign_field_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_tier text not null check (exposure_tier in (
    'none','low','medium','high','critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_exposure_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_warranty_reg_capa_actions_r3356 enable row level security;

create index if not exists idx_oem_warranty_capa_r3356_log on public.oem_warranty_reg_capa_actions_r3356(reg_log_id);
create index if not exists idx_oem_warranty_capa_r3356_status on public.oem_warranty_reg_capa_actions_r3356(capa_status);

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

  -- 14 install registration rows
  insert into public.oem_warranty_reg_r3356 (
    organization_id, engineer_name, hospital_name, install_code, equipment_type,
    oem_vendor, serial_number, install_date, warranty_months, registration_deadline,
    registration_submitted, registration_date, oem_activation_confirmed,
    warranty_start_date, warranty_end_date, days_to_deadline,
    blocking_reason, registration_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.code, q.eqt,
    q.vend, q.sn, q.idt::date, q.wmo, q.rdl::date,
    q.rsub, q.rdt::date, q.oac,
    q.wsd::date, q.wed::date, q.dtd,
    q.brs, q.rv, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai Greams Road','INS-APL-3301','imaging','ge_healthcare','GE-CT-88213','2026-05-10',60,'2026-06-09',true,'2026-05-22',true,'2026-05-10','2031-05-10',-40,'none','activated','Revolution CT registered day 12; OEM activation confirmed'),
    ('Anita Desai','Fortis Gurgaon','INS-FRT-3302','patient_monitoring','mindray','MND-MON-4471','2026-06-01',24,'2026-07-16',true,'2026-06-20',true,'2026-06-01','2028-06-01',-3,'none','activated','BeneVision central station + 8 monitors; activated within window'),
    ('Suresh Iyer','Manipal Bengaluru Old Airport Rd','INS-MNP-3303','dialysis','fresenius_medical','FMC-4008S-2210','2026-07-02',24,'2026-08-16',false,null,false,null,null,28,'none','pending_in_window','5x 4008S units; registration queued, still within window'),
    ('Vikram Nair','AIIMS Delhi Ansari Nagar','INS-AIM-3304','ventilator','draeger','DRG-EVITA-7781','2026-06-25',36,'2026-08-09',false,null,false,null,null,21,'customer_info_pending','pending_in_window','Evita V600; awaiting biomed asset codes before portal submission'),
    ('Priya Menon','CMC Vellore','INS-CMC-3305','lab_analyzer','roche_diagnostics','RCH-COBAS-5533','2026-05-05',12,'2026-06-04',false,null,false,null,null,-45,'portal_error','overdue_at_risk','cobas c311; OEM portal rejected serial twice, past deadline, escalation raised'),
    ('Arjun Reddy','KIMS Hyderabad','INS-KIM-3306','infusion_pump','baxter','BAX-SIGMA-9012','2026-05-18',24,'2026-07-02',false,null,false,null,null,-17,'engineer_delay','overdue_at_risk','12x Sigma Spectrum pumps; field engineer missed registration visit'),
    ('Rajesh Kumar','Apollo Chennai Greams Road','INS-APL-3307','imaging','philips','PHL-MR-6620','2026-03-01',60,'2026-04-15',false,null,false,null,null,-95,'missing_docs','lapsed_void','Ingenia MR; install certificate never filed, window lapsed, high exposure'),
    ('Suresh Iyer','Manipal Bengaluru Old Airport Rd','INS-MNP-3308','dialysis','baxter','BAX-HD-3341','2026-02-20',24,'2026-04-05',false,null,false,null,null,-105,'engineer_delay','lapsed_void','HD unit; no registration submitted, coverage void, AMC quote pending'),
    ('Anita Desai','Fortis Gurgaon','INS-FRT-3309','patient_monitoring','nihon_kohden','NK-LIFESCOPE-2288','2026-04-10',36,'2026-05-25',true,'2026-06-12',true,'2026-04-10','2029-04-10',-55,'none','activated_late','Life Scope; submitted 18 days late, OEM granted backdated activation'),
    ('Vikram Nair','AIIMS Delhi Ansari Nagar','INS-AIM-3310','ventilator','mindray','MND-SV300-7712','2026-04-22',24,'2026-06-06',true,'2026-06-24',true,'2026-04-22','2028-04-22',-43,'none','activated_late','SV300; late submission after customer docs delay, activation confirmed'),
    ('Priya Menon','CMC Vellore','INS-CMC-3311','lab_analyzer','siemens_healthineers','SIE-ATELLICA-4419','2026-06-15',24,'2026-07-30',true,'2026-07-01',true,'2026-06-15','2028-06-15',11,'none','activated','Atellica CH; registered ahead of deadline, activation live'),
    ('Arjun Reddy','KIMS Hyderabad','INS-KIM-3312','imaging','siemens_healthineers','SIE-CT-7788','2026-06-28',60,'2026-08-12',true,'2026-07-15',false,null,null,24,'none','pending_in_window','SOMATOM CT; submitted, awaiting OEM activation confirmation'),
    ('Deepa Krishnan','Yashoda Hyderabad Somajiguda','INS-YSH-3313','infusion_pump','bpl_medical','BPL-INF-1120','2026-05-28',12,'2026-07-12',false,null,false,null,null,-7,'customer_info_pending','overdue_at_risk','6x infusion pumps; customer bed-unit mapping pending, deadline just missed'),
    ('Deepa Krishnan','Yashoda Hyderabad Somajiguda','INS-YSH-3314','infusion_pump','bpl_medical','BPL-INF-1155','2026-06-30',12,'2026-08-14',true,'2026-07-10',true,'2026-06-30','2027-06-30',26,'none','activated','Single infusion pump; quick registration, activation confirmed')
  ) as q(eng, hosp, code, eqt, vend, sn, idt, wmo, rdl, rsub, rdt, oac, wsd, wed, dtd, brs, rv, nt);

  -- CAPA seed — attach to specific installs via install_code
  insert into public.oem_warranty_reg_capa_actions_r3356 (
    reg_log_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_tier, target_closure_date, actual_closure_date,
    estimated_exposure_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.xt, q.tcd::date, q.acd::date,
    q.exp, q.nt
  from (values
    ('INS-CMC-3305','portal_submission_error','oem_portal_downtime','resubmit_registration','escalated','high','2026-07-22',null,320000.00,'Roche portal rejecting serial; escalated to account manager for manual registration'),
    ('INS-KIM-3306','registration_overdue','engineer_scheduling_delay','assign_field_engineer','in_progress','medium','2026-07-21',null,240000.00,'Reassigned to Hyderabad field engineer to complete Baxter pump registration this week'),
    ('INS-APL-3307','warranty_lapsed','install_paperwork_incomplete','escalate_to_oem_account_manager','escalated','critical','2026-07-20',null,1450000.00,'Philips MR warranty void; escalating for goodwill reinstatement, high financial exposure'),
    ('INS-MNP-3308','warranty_lapsed','engineer_scheduling_delay','escalate_to_oem_account_manager','open','high','2026-07-25',null,680000.00,'Baxter HD coverage void; pursuing paid AMC bridge quote for customer'),
    ('INS-AIM-3304','customer_info_gap','customer_docs_pending','collect_customer_documents','in_progress','low','2026-07-24',null,0.00,'Chasing AIIMS biomed for asset codes; still within registration window'),
    ('INS-YSH-3313','deadline_at_risk','customer_docs_pending','expedite_portal_submission','overdue','medium','2026-07-15',null,180000.00,'Bed-unit mapping pending; CAPA past target, escalating to customer PM'),
    ('INS-AIM-3310','activation_not_confirmed','vendor_activation_backlog','request_backdated_activation','closed','low','2026-06-30','2026-06-24',0.00,'Mindray granted backdated activation; CAPA closed, coverage intact')
  ) as q(code, fc, rc, ca, cst, xt, tcd, acd, exp, nt)
  join public.oem_warranty_reg_r3356 e
    on e.organization_id = v_org_id and e.install_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Registration verdict distribution
create or replace function public.founder_r3356_registration_verdict_rollup()
returns table(registration_verdict text, installs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_warranty_reg_r3356)
  select l.registration_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oem_warranty_reg_r3356 l
  group by l.registration_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_registration_verdict_rollup() from public, anon;
grant execute on function public.founder_r3356_registration_verdict_rollup() to authenticated;

-- 2) Engineer-level compliance scorecard
create or replace function public.founder_r3356_engineer_scorecard()
returns table(
  engineer_name text,
  total_installs bigint,
  activated bigint,
  pending bigint,
  overdue_at_risk bigint,
  lapsed_void bigint,
  activated_late bigint,
  submitted bigint,
  activation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.registration_verdict = 'activated')::bigint,
    count(*) filter (where l.registration_verdict = 'pending_in_window')::bigint,
    count(*) filter (where l.registration_verdict = 'overdue_at_risk')::bigint,
    count(*) filter (where l.registration_verdict = 'lapsed_void')::bigint,
    count(*) filter (where l.registration_verdict = 'activated_late')::bigint,
    count(*) filter (where l.registration_submitted = true)::bigint,
    round(100.0 * count(*) filter (where l.registration_verdict in ('activated','activated_late'))::numeric / nullif(count(*),0), 1)
  from public.oem_warranty_reg_r3356 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3356_engineer_scorecard() to authenticated;

-- 3) Equipment type × OEM vendor matrix
create or replace function public.founder_r3356_equipment_vendor_matrix()
returns table(equipment_type text, oem_vendor text, installs bigint, activated bigint, lapsed bigint, avg_days_to_deadline numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.oem_vendor, count(*)::bigint,
    count(*) filter (where l.registration_verdict in ('activated','activated_late'))::bigint,
    count(*) filter (where l.registration_verdict = 'lapsed_void')::bigint,
    round(avg(l.days_to_deadline), 1)
  from public.oem_warranty_reg_r3356 l
  group by l.equipment_type, l.oem_vendor
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_equipment_vendor_matrix() from public, anon;
grant execute on function public.founder_r3356_equipment_vendor_matrix() to authenticated;

-- 4) Daily registration trend
create or replace function public.founder_r3356_daily_registration_trend()
returns table(install_date date, installs bigint, activated bigint, overdue_at_risk bigint, lapsed_void bigint, not_submitted bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.install_date,
    count(*)::bigint,
    count(*) filter (where l.registration_verdict in ('activated','activated_late'))::bigint,
    count(*) filter (where l.registration_verdict = 'overdue_at_risk')::bigint,
    count(*) filter (where l.registration_verdict = 'lapsed_void')::bigint,
    count(*) filter (where l.registration_submitted = false)::bigint
  from public.oem_warranty_reg_r3356 l
  group by l.install_date
  order by l.install_date desc;
end;
$$;

revoke execute on function public.founder_r3356_daily_registration_trend() from public, anon;
grant execute on function public.founder_r3356_daily_registration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3356_capa_status_board()
returns table(capa_status text, findings bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.oem_warranty_reg_capa_actions_r3356 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_capa_status_board() from public, anon;
grant execute on function public.founder_r3356_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3356_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_warranty_reg_capa_actions_r3356)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oem_warranty_reg_capa_actions_r3356 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3356_root_cause_pareto() to authenticated;

-- 7) Exposure / financial-risk digest
create or replace function public.founder_r3356_exposure_risk_digest()
returns table(exposure_tier text, findings bigint, open_findings bigint, total_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.exposure_tier, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_exposure_rupees),0)::numeric
  from public.oem_warranty_reg_capa_actions_r3356 c
  group by c.exposure_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3356_exposure_risk_digest() from public, anon;
grant execute on function public.founder_r3356_exposure_risk_digest() to authenticated;

-- 8) High-risk registration queue (individual at-risk installs)
create or replace function public.founder_r3356_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  install_code text,
  equipment_type text,
  oem_vendor text,
  install_date date,
  registration_deadline date,
  days_to_deadline int,
  blocking_reason text,
  registration_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.install_code, l.equipment_type, l.oem_vendor,
    l.install_date, l.registration_deadline, l.days_to_deadline,
    l.blocking_reason, l.registration_verdict, l.notes
  from public.oem_warranty_reg_r3356 l
  where l.registration_verdict in ('overdue_at_risk','lapsed_void','pending_in_window','activated_late')
     or l.registration_submitted = false
     or l.oem_activation_confirmed = false
     or l.blocking_reason <> 'none'
  order by l.days_to_deadline asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3356_high_risk_queue() from public, anon;
grant execute on function public.founder_r3356_high_risk_queue() to authenticated;
