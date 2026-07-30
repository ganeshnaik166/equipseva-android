-- Round 3642: Medical-Device Import-License / Registration-Certificate Portfolio Board
-- Import-license / registration-certificate (Form MD-14/MD-15) portfolio + validity per device/OEM —
-- license form × renewal status × issue/expiry dates × days-to-expiry × renewal lead × agent-appointment
-- validity × dossier readiness × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: import_license_r3642 — per-device import-license / registration-certificate portfolio
-- =============================================================================
create table if not exists public.import_license_r3642 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_name text not null,
  oem_name text not null,
  period_month date not null,
  registration_cert_no text not null,
  issue_date date,
  expiry_date date,
  days_to_expiry int,
  renewal_lead_days int,
  agent_appointment_valid boolean not null,
  dossier_readiness_pct numeric(5,2),
  license_form text not null check (license_form in (
    'md_14_import','md_15_import_license','registration_certificate','free_sale_cert','nec_certificate'
  )),
  renewal_status text not null check (renewal_status in (
    'valid','renewal_due','under_renewal','expired','application_pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.import_license_r3642 enable row level security;

create index if not exists idx_import_license_r3642_org on public.import_license_r3642(organization_id);
create index if not exists idx_import_license_r3642_expiry on public.import_license_r3642(expiry_date);
create index if not exists idx_import_license_r3642_status on public.import_license_r3642(renewal_status);

-- =============================================================================
-- TABLE 2: import_license_capa_actions_r3642 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.import_license_capa_actions_r3642 (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.import_license_r3642(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'registration_cert_expired','renewal_application_overdue','agent_appointment_lapsed',
    'dossier_incomplete','test_license_gap','labelling_noncompliance','fee_payment_pending',
    'oem_document_shortfall','plant_master_file_outdated','postmarket_surveillance_gap'
  )),
  root_cause text not null check (root_cause in (
    'oem_delay_in_documents','regulatory_fee_not_paid','agent_agreement_expired',
    'dossier_preparation_backlog','cdsco_query_unresolved','notified_body_cert_lapsed',
    'internal_tracking_miss','translation_pending','plant_audit_pending','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','pay_regulatory_fee','renew_agent_agreement','complete_dossier',
    'respond_to_cdsco_query','obtain_updated_oem_docs','update_plant_master_file',
    'submit_free_sale_certificate','engage_regulatory_consultant','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','submitted_to_cdsco','query_raised','closed','escalated','overdue'
  )),
  owner text,
  estimated_cost_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.import_license_capa_actions_r3642 enable row level security;

create index if not exists idx_import_license_capa_r3642_lic on public.import_license_capa_actions_r3642(license_id);
create index if not exists idx_import_license_capa_r3642_status on public.import_license_capa_actions_r3642(capa_status);

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

  -- 16 import-license portfolio rows
  insert into public.import_license_r3642 (
    organization_id, device_name, oem_name, period_month, registration_cert_no,
    issue_date, expiry_date, days_to_expiry, renewal_lead_days, agent_appointment_valid,
    dossier_readiness_pct, license_form, renewal_status, trend_dir, notes
  )
  select v_org_id, q.dname, q.oem, q.pmon::date, q.cert,
    q.isdt::date, q.exdt::date, q.d2e, q.leaddays, q.agent,
    q.dossier, q.lform, q.rstat, q.trnd, q.nt
  from (values
    ('ICU Ventilator','Draeger Medical','2026-07-01','MD15-2021-DRG-0456',
     '2021-08-15','2024-08-14',-715,180,true,100,'md_15_import_license','expired','worsening','MD-15 lapsed — renewal application not filed in time'),
    ('Anesthesia Workstation','GE Healthcare','2026-07-01','MD15-2023-GE-1187',
     '2023-03-10','2026-03-09',-142,180,true,88,'md_15_import_license','under_renewal','improving','Renewal filed with CDSCO; awaiting grant of endorsement'),
    ('Patient Monitor','Mindray','2026-07-01','MD14-2024-MDR-2290',
     '2024-05-20','2027-05-19',293,120,true,95,'md_14_import','valid','stable','MD-14 import registration valid and current'),
    ('Infusion Pump','B. Braun','2026-07-01','RC-2022-BB-0771',
     '2022-09-01','2025-08-31',-333,150,false,60,'registration_certificate','expired','worsening','RC expired and Indian authorised-agent appointment lapsed'),
    ('Hemodialysis Machine','Fresenius Medical','2026-07-01','MD15-2024-FRE-3312',
     '2024-01-12','2027-01-11',165,180,true,90,'md_15_import_license','renewal_due','stable','Renewal window opening — start dossier compilation'),
    ('Defibrillator','Philips Healthcare','2026-07-01','MD14-2023-PHL-1902',
     '2023-11-05','2026-11-04',97,120,true,72,'md_14_import','renewal_due','worsening','Approaching expiry; dossier only 72 pct ready'),
    ('Mobile C-Arm','Siemens Healthineers','2026-07-01','RC-2024-SIE-4410',
     '2024-06-18','2027-06-17',322,150,true,98,'registration_certificate','valid','improving','C-arm RC valid, dossier strong for early renewal'),
    ('Syringe Pump','Terumo','2026-07-01','FSC-2025-TER-5501',
     '2025-02-01','2027-01-31',185,90,true,100,'free_sale_cert','valid','stable','Free-sale certificate current for tender submissions'),
    ('Ultrasound System','Canon Medical','2026-07-01','MD15-2022-CAN-0623',
     '2022-12-20','2025-12-19',-223,180,true,55,'md_15_import_license','application_pending','worsening','Fresh application pending CDSCO deficiency query response'),
    ('Surgical Diathermy','Erbe','2026-07-01','NEC-2025-ERB-6620',
     '2025-04-15','2027-04-14',258,90,true,80,'nec_certificate','valid','stable','No-encumbrance certificate valid'),
    ('CT Scanner','GE Healthcare','2026-07-01','MD14-2023-GE-1450',
     '2023-07-22','2026-07-21',-9,120,true,68,'md_14_import','renewal_due','worsening','Just expired last week; expedite renewal filing'),
    ('Blood Gas Analyzer','Radiometer','2026-07-01','RC-2024-RAD-4802',
     '2024-09-30','2027-09-29',426,150,false,45,'registration_certificate','under_renewal','improving','Under renewal but agent agreement not yet renewed'),
    ('Transport Ventilator','Hamilton Medical','2026-07-01','MD15-2025-HAM-7013',
     '2025-06-05','2028-06-04',675,180,true,100,'md_15_import_license','valid','stable','New MD-15 granted with long validity'),
    ('Infant Warmer','Atom Medical','2026-07-01','MD14-2022-ATM-0988',
     '2022-10-10','2025-10-09',-294,120,true,50,'md_14_import','expired','worsening','Expired; dossier incomplete, low readiness'),
    ('Dental Chair Unit','Dentsply Sirona','2026-07-01','FSC-2024-DEN-5230',
     '2024-08-01','2026-07-31',1,90,true,85,'free_sale_cert','renewal_due','stable','FSC expiring imminently — renewal fee under process'),
    ('Endoscopy Tower','Olympus Medical','2026-07-01','MD15-2023-OLY-1655',
     '2023-05-14','2026-05-13',-78,180,true,92,'md_15_import_license','application_pending','improving','Renewal application submitted, awaiting CDSCO scrutiny')
  ) as q(dname, oem, pmon, cert, isdt, exdt, d2e, leaddays, agent, dossier, lform, rstat, trnd, nt);

  -- CAPA seed — attach to specific licenses via registration_cert_no
  insert into public.import_license_capa_actions_r3642 (
    license_id, finding_category, root_cause, corrective_action,
    capa_status, owner, estimated_cost_rupees, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ownr, q.cost, q.tcd::date, q.acd::date, q.nt
  from (values
    ('MD15-2021-DRG-0456','registration_cert_expired','internal_tracking_miss','file_renewal_application','open','Regulatory Affairs - Priya Nair',85000,'2026-08-15',null,'File fresh MD-15 renewal; lapse flagged in internal audit'),
    ('RC-2022-BB-0771','agent_appointment_lapsed','agent_agreement_expired','renew_agent_agreement','in_progress','Legal - Rahul Mehta',40000,'2026-08-01',null,'Renew Indian authorised-agent agreement then refile RC'),
    ('MD15-2022-CAN-0623','dossier_incomplete','cdsco_query_unresolved','respond_to_cdsco_query','query_raised','Regulatory Affairs - Priya Nair',120000,'2026-08-20',null,'Respond to CDSCO deficiency letter with updated dossier'),
    ('MD14-2023-GE-1450','renewal_application_overdue','dossier_preparation_backlog','complete_dossier','escalated','Regulatory Affairs - Anil Kumar',95000,'2026-08-10',null,'Expedite CT-scanner renewal; escalated to management'),
    ('MD14-2022-ATM-0988','dossier_incomplete','oem_delay_in_documents','obtain_updated_oem_docs','open','Sourcing - Meena Iyer',60000,'2026-08-25',null,'OEM plant master file and free-sale certificate awaited'),
    ('MD14-2023-PHL-1902','renewal_application_overdue','regulatory_fee_not_paid','pay_regulatory_fee','in_progress','Finance - Deepak Shah',50000,'2026-09-01',null,'Regulatory fee sanctioned; payment in process'),
    ('RC-2024-RAD-4802','agent_appointment_lapsed','translation_pending','renew_agent_agreement','open','Legal - Rahul Mehta',35000,'2026-09-05',null,'Agent-agreement renewal plus notarised translations pending'),
    ('FSC-2024-DEN-5230','fee_payment_pending','regulatory_fee_not_paid','pay_regulatory_fee','closed','Finance - Deepak Shah',25000,'2026-07-20','2026-07-18','FSC renewal fee paid; certificate renewed'),
    ('MD15-2023-OLY-1655','postmarket_surveillance_gap','plant_audit_pending','engage_regulatory_consultant','submitted_to_cdsco','Regulatory Affairs - Anil Kumar',110000,'2026-08-30',null,'Endoscopy renewal submitted; consultant engaged for PMS closure')
  ) as q(cert, fc, rc, ca, cst, ownr, cost, tcd, acd, nt)
  join public.import_license_r3642 e
    on e.organization_id = v_org_id and e.registration_cert_no = q.cert;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal-status distribution
create or replace function public.founder_r3642_renewal_status_rollup()
returns table(renewal_status text, licenses bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.import_license_r3642)
  select l.renewal_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.import_license_r3642 l
  group by l.renewal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_renewal_status_rollup() from public, anon;
grant execute on function public.founder_r3642_renewal_status_rollup() to authenticated;

-- 2) OEM-level portfolio scorecard
create or replace function public.founder_r3642_oem_scorecard()
returns table(
  oem_name text,
  total_licenses bigint,
  valid bigint,
  renewal_due bigint,
  expired bigint,
  agent_invalid bigint,
  avg_days_to_expiry numeric,
  avg_dossier_readiness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_name,
    count(*)::bigint,
    count(*) filter (where l.renewal_status = 'valid')::bigint,
    count(*) filter (where l.renewal_status = 'renewal_due')::bigint,
    count(*) filter (where l.renewal_status = 'expired')::bigint,
    count(*) filter (where l.agent_appointment_valid = false)::bigint,
    round(avg(l.days_to_expiry), 0),
    round(avg(l.dossier_readiness_pct), 1)
  from public.import_license_r3642 l
  group by l.oem_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_oem_scorecard() from public, anon;
grant execute on function public.founder_r3642_oem_scorecard() to authenticated;

-- 3) License-form × renewal-status matrix
create or replace function public.founder_r3642_license_form_status_matrix()
returns table(license_form text, renewal_status text, licenses bigint, avg_days_to_expiry numeric, avg_dossier_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.license_form, l.renewal_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 0),
    round(avg(l.dossier_readiness_pct), 1)
  from public.import_license_r3642 l
  group by l.license_form, l.renewal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_license_form_status_matrix() from public, anon;
grant execute on function public.founder_r3642_license_form_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3642_monthly_expiry_trend()
returns table(expiry_month date, licenses_expiring bigint, expired bigint, renewal_due bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.expiry_date)::date,
    count(*)::bigint,
    count(*) filter (where l.renewal_status = 'expired')::bigint,
    count(*) filter (where l.renewal_status = 'renewal_due')::bigint,
    round(avg(l.days_to_expiry), 0)
  from public.import_license_r3642 l
  where l.expiry_date is not null
  group by date_trunc('month', l.expiry_date)
  order by date_trunc('month', l.expiry_date);
end;
$$;

revoke execute on function public.founder_r3642_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3642_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3642_capa_status_board()
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
  from public.import_license_capa_actions_r3642 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_capa_status_board() from public, anon;
grant execute on function public.founder_r3642_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3642_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.import_license_capa_actions_r3642)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.import_license_capa_actions_r3642 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3642_root_cause_pareto() to authenticated;

-- 7) Expiry-exposure digest (days-to-expiry buckets)
create or replace function public.founder_r3642_expiry_exposure_digest()
returns table(exposure_bucket text, licenses bigint, renewal_due bigint, expired bigint, avg_days_to_expiry numeric, avg_dossier_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with b as (
    select l.*,
      case
        when l.days_to_expiry is null then 'unknown'
        when l.days_to_expiry < 0 then 'expired'
        when l.days_to_expiry <= 30 then 'within_30d'
        when l.days_to_expiry <= 90 then 'within_90d'
        when l.days_to_expiry <= 180 then 'within_180d'
        else 'over_180d'
      end as bucket
    from public.import_license_r3642 l
  )
  select b.bucket, count(*)::bigint,
    count(*) filter (where b.renewal_status = 'renewal_due')::bigint,
    count(*) filter (where b.renewal_status = 'expired')::bigint,
    round(avg(b.days_to_expiry), 0),
    round(avg(b.dossier_readiness_pct), 1)
  from b
  group by b.bucket
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3642_expiry_exposure_digest() from public, anon;
grant execute on function public.founder_r3642_expiry_exposure_digest() to authenticated;

-- 8) High-risk queue (expired / renewal-due / weak dossier)
create or replace function public.founder_r3642_high_risk_queue()
returns table(
  device_name text,
  oem_name text,
  registration_cert_no text,
  license_form text,
  expiry_date date,
  days_to_expiry int,
  renewal_status text,
  dossier_readiness_pct numeric,
  agent_appointment_valid boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.oem_name, l.registration_cert_no, l.license_form,
    l.expiry_date, l.days_to_expiry, l.renewal_status,
    l.dossier_readiness_pct, l.agent_appointment_valid, l.notes
  from public.import_license_r3642 l
  where l.renewal_status in ('expired','renewal_due','application_pending','under_renewal')
     or l.days_to_expiry < 90
     or l.dossier_readiness_pct < 75
     or l.agent_appointment_valid = false
  order by l.days_to_expiry asc nulls last, l.oem_name;
end;
$$;

revoke execute on function public.founder_r3642_high_risk_queue() from public, anon;
grant execute on function public.founder_r3642_high_risk_queue() to authenticated;
