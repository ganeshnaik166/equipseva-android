-- Round 3349: Founder CDSCO / AERB Regulatory-License & Inspection-Readiness Board
-- Regulatory register — regulatory body × license type × renewal status × inspection outcome × open observations × penalty exposure × readiness verdict × CAPA closure

-- =============================================================================
-- TABLE 1: regulatory_license_r3349 — per license / statutory obligation
-- =============================================================================
create table if not exists public.regulatory_license_r3349 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  regulatory_body text not null check (regulatory_body in (
    'cdsco','aerb','legal_metrology','state_drug_authority','bis','cpcb'
  )),
  license_type text not null check (license_type in (
    'device_import_registration','service_provider_registration','radiation_handling_license',
    'measuring_instrument_verification','component_certification','pollution_consent'
  )),
  reference_no text not null,
  scope text not null,
  issue_date date not null,
  expiry_date date not null,
  days_to_expiry int not null,
  renewal_status text not null check (renewal_status in (
    'valid','renewal_due','under_process','expired','show_cause'
  )),
  last_inspection_date date,
  inspection_outcome text not null check (inspection_outcome in (
    'compliant','minor_observations','major_ncr','not_inspected'
  )),
  open_observations int not null default 0,
  penalty_exposure_rupees numeric(14,2) not null default 0,
  responsible_owner text not null,
  readiness_verdict text not null check (readiness_verdict in (
    'fully_compliant','renewal_action','observations_open','inspection_prep_needed','critical_gap'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.regulatory_license_r3349 enable row level security;

create index if not exists idx_regulatory_license_r3349_org on public.regulatory_license_r3349(organization_id);
create index if not exists idx_regulatory_license_r3349_expiry on public.regulatory_license_r3349(expiry_date);
create index if not exists idx_regulatory_license_r3349_verdict on public.regulatory_license_r3349(readiness_verdict);

-- =============================================================================
-- TABLE 2: regulatory_license_capa_actions_r3349 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.regulatory_license_capa_actions_r3349 (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.regulatory_license_r3349(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'license_renewal_overdue','inspection_observation_open','radiation_survey_gap',
    'measuring_instrument_verification_due','import_registration_lapse','pollution_consent_expiry',
    'show_cause_response_due','document_traceability_gap','staff_certification_gap','audit_prep_incomplete'
  )),
  root_cause text not null check (root_cause in (
    'renewal_application_delay','regulator_backlog','missing_documentation','qualified_person_vacancy',
    'fee_payment_pending','scope_change_unfiled','vendor_certificate_lapsed','internal_tracking_failure',
    'pending_investigation','policy_ambiguity'
  )),
  corrective_action text not null check (corrective_action in (
    'file_renewal_application','submit_observation_response','conduct_radiation_survey','schedule_verification',
    'appoint_qualified_person','pay_regulatory_fee','update_scope_filing','compile_audit_dossier',
    'engage_regulatory_consultant','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','aerb_directive','legal_metrology_penalty','license_suspension_risk','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.regulatory_license_capa_actions_r3349 enable row level security;

create index if not exists idx_regulatory_capa_r3349_license on public.regulatory_license_capa_actions_r3349(license_id);
create index if not exists idx_regulatory_capa_r3349_status on public.regulatory_license_capa_actions_r3349(capa_status);

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

  -- 14 regulatory-license rows
  insert into public.regulatory_license_r3349 (
    organization_id, site_name, regulatory_body, license_type, reference_no, scope,
    issue_date, expiry_date, days_to_expiry, renewal_status,
    last_inspection_date, inspection_outcome, open_observations, penalty_exposure_rupees,
    responsible_owner, readiness_verdict, notes
  )
  select v_org_id, q.site, q.body, q.ltype, q.ref, q.scope,
    q.isd::date, q.exd::date, q.dte::int, q.rst,
    q.lid::date, q.iout, q.oobs::int, q.pen::numeric,
    q.owner, q.verdict, q.nt
  from (values
    ('AIIMS New Delhi Ansari Nagar','aerb','radiation_handling_license','AERB/RSD/2023/DL/0456',
     'Servicing of linac & CT radiation installations at AIIMS radiotherapy block',
     '2023-02-01','2027-01-31',196,'valid',
     '2025-11-10','compliant',0,0,
     'Dr. Anil Menon (RSO)','fully_compliant','RSO-endorsed; TLD survey clean, no findings'),
    ('Tata Memorial Mumbai','aerb','radiation_handling_license','AERB/RSD/2021/MH/1188',
     'Linac & brachytherapy service registration for Tata Memorial radiotherapy',
     '2021-09-15','2026-09-15',58,'renewal_due',
     '2025-06-20','minor_observations',2,0,
     'Ramesh Iyer','renewal_action','Renewal e-LORA form pending; two survey observations open'),
    ('Apollo Chennai Greams Road','cdsco','service_provider_registration','CDSCO/MD/SP/2022/TN/3391',
     'Medical-device service-provider registration for Tamil Nadu operations',
     '2022-08-10','2026-08-10',22,'renewal_due',
     '2024-12-05','compliant',0,0,
     'Priya Nair','renewal_action','Renewal filing due in 3 weeks; dossier compiled'),
    ('Fortis Gurgaon','cdsco','device_import_registration','CDSCO/MD/IMP/2024/HR/7742',
     'Import registration for refurbished mobile C-arm units',
     '2024-01-30','2026-11-30',134,'under_process',
     null,'not_inspected',0,0,
     'Vikram Sethi','renewal_action','MD-15 renewal under process at CDSCO HQ; query awaited'),
    ('Manipal Bengaluru Old Airport Road','legal_metrology','measuring_instrument_verification','LMD/KA/VER/2025/00912',
     'Stamping & verification of infusion pumps and weighing scales',
     '2025-03-31','2026-07-31',12,'renewal_due',
     '2025-03-15','minor_observations',1,5000,
     'Suresh Rao','observations_open','Verification stamp expiring; one calibration observation open'),
    ('CMC Vellore','aerb','radiation_handling_license','AERB/RSD/2020/TN/0733',
     'CT & fluoroscopy service radiation-handling license, Vellore campus',
     '2020-05-01','2026-07-25',6,'show_cause',
     '2026-05-02','major_ncr',4,250000,
     'Dr. George Thomas','critical_gap','Show-cause issued after major NCR; suspension risk imminent'),
    ('KIMS Hyderabad','cdsco','service_provider_registration','CDSCO/MD/SP/2023/TG/5120',
     'Medical-device service-provider registration for Telangana operations',
     '2024-03-31','2028-03-31',621,'valid',
     '2025-09-18','compliant',0,0,
     'Lakshmi Prasad','fully_compliant','Multi-year registration; last audit clean'),
    ('Narayana Health Bengaluru','bis','component_certification','BIS/CM-L/2024/7781234',
     'BIS certification for autoclave pressure-vessel components supplied',
     '2024-10-20','2026-10-20',93,'valid',
     '2025-08-01','compliant',0,0,
     'Mohan Kumar','fully_compliant','ISI-marked; factory surveillance passed'),
    ('Medanta Gurgaon','cpcb','pollution_consent','HSPCB/BMW/2023/GGN/4456',
     'Consent-to-operate for biomedical-waste handling & DG-set emissions',
     '2023-09-01','2026-08-31',43,'renewal_due',
     '2025-10-12','minor_observations',1,0,
     'Rahul Bansal','renewal_action','CTO renewal due; one BMW-log observation open'),
    ('Kokilaben Mumbai','state_drug_authority','service_provider_registration','FDA-MH/MD/2024/SP/2290',
     'State drug-authority service registration for Maharashtra device servicing',
     '2024-11-20','2026-12-15',149,'under_process',
     '2024-11-20','minor_observations',2,0,
     'Farida Khan','observations_open','Renewal under process; two documentation observations open'),
    ('SGPGI Lucknow','aerb','radiation_handling_license','AERB/RSD/2019/UP/0501',
     'Brachytherapy after-loader service radiation-handling license',
     '2019-06-30','2026-06-30',-19,'expired',
     '2025-12-10','major_ncr',3,150000,
     'Dr. Alok Srivastava','critical_gap','License lapsed 19 days ago; major NCR unresolved'),
    ('PGIMER Chandigarh','legal_metrology','measuring_instrument_verification','LMD/CH/VER/2026/00114',
     'Verification of clinical weighing & dispensing instruments',
     '2026-01-01','2027-02-28',224,'valid',
     '2026-01-15','compliant',0,0,
     'Harpreet Singh','fully_compliant','Fresh verification stamp; no observations'),
    ('Amrita Kochi','cdsco','device_import_registration','CDSCO/MD/IMP/2024/KL/6018',
     'Import registration for imported dialysis-machine spares',
     '2024-09-05','2026-09-05',48,'renewal_due',
     null,'not_inspected',0,0,
     'Deepak Nair','inspection_prep_needed','Renewal due; site not yet inspected, prep dossier pending'),
    ('NIMHANS Bengaluru','cpcb','pollution_consent','KSPCB/BMW/2024/BLR/9903',
     'Consent-to-operate for biomedical-waste segregation at NIMHANS',
     '2024-04-01','2027-03-31',255,'valid',
     '2025-07-22','compliant',0,0,
     'Girish Rao','fully_compliant','CTO valid to FY27; surveillance clean')
  ) as q(site, body, ltype, ref, scope, isd, exd, dte, rst, lid, iout, oobs, pen, owner, verdict, nt);

  -- CAPA seed — attach to specific licenses by reference_no
  insert into public.regulatory_license_capa_actions_r3349 (
    license_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('AERB/RSD/2020/TN/0733','show_cause_response_due','renewal_application_delay','submit_observation_response',
     'escalated','aerb_directive','2026-07-24',null,300000.00,'Show-cause reply drafting with RSO; board escalation raised'),
    ('AERB/RSD/2019/UP/0501','license_renewal_overdue','regulator_backlog','file_renewal_application',
     'overdue','license_suspension_risk','2026-07-10',null,200000.00,'e-LORA renewal stuck in AERB queue; interim halt on service'),
    ('LMD/KA/VER/2025/00912','measuring_instrument_verification_due','fee_payment_pending','schedule_verification',
     'in_progress','legal_metrology_penalty','2026-07-28',null,25000.00,'Verification fee challan raised; inspector slot requested'),
    ('AERB/RSD/2021/MH/1188','radiation_survey_gap','qualified_person_vacancy','appoint_qualified_person',
     'open','aerb_directive','2026-08-20',null,120000.00,'RSO-II vacancy blocking survey closure; hiring in progress'),
    ('CDSCO/MD/SP/2022/TN/3391','license_renewal_overdue','missing_documentation','file_renewal_application',
     'verification_pending','cdsco_notifiable','2026-08-01',null,15000.00,'Renewal filed on SUGAM; awaiting acknowledgement'),
    ('HSPCB/BMW/2023/GGN/4456','pollution_consent_expiry','scope_change_unfiled','update_scope_filing',
     'closed','internal_only','2026-07-15','2026-07-12',8000.00,'DG-set capacity change filed; CTO amendment received'),
    ('FDA-MH/MD/2024/SP/2290','inspection_observation_open','vendor_certificate_lapsed','compile_audit_dossier',
     'in_progress','none','2026-08-10',null,12000.00,'Vendor calibration certs being re-collected for dossier')
  ) as q(ref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.regulatory_license_r3349 e
    on e.organization_id = v_org_id and e.reference_no = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness-verdict distribution
create or replace function public.founder_r3349_readiness_verdict_rollup()
returns table(readiness_verdict text, licenses bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.regulatory_license_r3349)
  select l.readiness_verdict, count(*)::bigint,
         coalesce(sum(l.penalty_exposure_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.regulatory_license_r3349 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3349_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3349_readiness_verdict_rollup() to authenticated;

-- 2) Site-level readiness scorecard
create or replace function public.founder_r3349_site_scorecard()
returns table(
  site_name text,
  total_licenses bigint,
  valid_licenses bigint,
  renewal_due bigint,
  expired_or_showcause bigint,
  open_observations bigint,
  total_penalty_exposure_rupees numeric,
  avg_days_to_expiry numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.renewal_status = 'valid')::bigint,
    count(*) filter (where l.renewal_status in ('renewal_due','under_process'))::bigint,
    count(*) filter (where l.renewal_status in ('expired','show_cause'))::bigint,
    coalesce(sum(l.open_observations),0)::bigint,
    coalesce(sum(l.penalty_exposure_rupees),0)::numeric,
    round(avg(l.days_to_expiry), 0)
  from public.regulatory_license_r3349 l
  group by l.site_name
  order by count(*) filter (where l.readiness_verdict in ('critical_gap','inspection_prep_needed','observations_open')) desc, l.site_name;
end;
$$;

revoke execute on function public.founder_r3349_site_scorecard() from public, anon;
grant execute on function public.founder_r3349_site_scorecard() to authenticated;

-- 3) Regulatory-body × license-type matrix
create or replace function public.founder_r3349_body_license_matrix()
returns table(regulatory_body text, license_type text, licenses bigint, compliant bigint, avg_days_to_expiry numeric, total_penalty_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.regulatory_body, l.license_type, count(*)::bigint,
    count(*) filter (where l.inspection_outcome = 'compliant')::bigint,
    round(avg(l.days_to_expiry), 0),
    coalesce(sum(l.penalty_exposure_rupees),0)::numeric
  from public.regulatory_license_r3349 l
  group by l.regulatory_body, l.license_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3349_body_license_matrix() from public, anon;
grant execute on function public.founder_r3349_body_license_matrix() to authenticated;

-- 4) Expiry-date renewal-calendar trend
create or replace function public.founder_r3349_expiry_trend()
returns table(expiry_date date, licenses bigint, renewal_due bigint, expired_or_showcause bigint, total_penalty_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.expiry_date,
    count(*)::bigint,
    count(*) filter (where l.renewal_status in ('renewal_due','under_process'))::bigint,
    count(*) filter (where l.renewal_status in ('expired','show_cause'))::bigint,
    coalesce(sum(l.penalty_exposure_rupees),0)::numeric
  from public.regulatory_license_r3349 l
  group by l.expiry_date
  order by l.expiry_date asc;
end;
$$;

revoke execute on function public.founder_r3349_expiry_trend() from public, anon;
grant execute on function public.founder_r3349_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3349_capa_status_board()
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
  from public.regulatory_license_capa_actions_r3349 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3349_capa_status_board() from public, anon;
grant execute on function public.founder_r3349_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3349_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.regulatory_license_capa_actions_r3349)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.regulatory_license_capa_actions_r3349 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3349_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3349_root_cause_pareto() to authenticated;

-- 7) Regulatory-body cost / risk digest
create or replace function public.founder_r3349_regulatory_body_risk_digest()
returns table(regulatory_body text, licenses bigint, open_observations bigint, critical_gaps bigint, total_penalty_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.regulatory_body, count(*)::bigint,
    coalesce(sum(l.open_observations),0)::bigint,
    count(*) filter (where l.readiness_verdict in ('critical_gap','inspection_prep_needed'))::bigint,
    coalesce(sum(l.penalty_exposure_rupees),0)::numeric
  from public.regulatory_license_r3349 l
  group by l.regulatory_body
  order by coalesce(sum(l.penalty_exposure_rupees),0) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3349_regulatory_body_risk_digest() from public, anon;
grant execute on function public.founder_r3349_regulatory_body_risk_digest() to authenticated;

-- 8) High-risk license queue (renewal / inspection concerns)
create or replace function public.founder_r3349_high_risk_queue()
returns table(
  site_name text,
  regulatory_body text,
  license_type text,
  reference_no text,
  expiry_date date,
  days_to_expiry int,
  renewal_status text,
  readiness_verdict text,
  penalty_exposure_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.regulatory_body, l.license_type, l.reference_no,
    l.expiry_date, l.days_to_expiry, l.renewal_status, l.readiness_verdict,
    l.penalty_exposure_rupees, l.notes
  from public.regulatory_license_r3349 l
  where l.readiness_verdict in ('observations_open','inspection_prep_needed','critical_gap')
     or l.renewal_status in ('renewal_due','under_process','expired','show_cause')
     or l.days_to_expiry < 60
  order by l.days_to_expiry asc, l.penalty_exposure_rupees desc;
end;
$$;

revoke execute on function public.founder_r3349_high_risk_queue() from public, anon;
grant execute on function public.founder_r3349_high_risk_queue() to authenticated;
