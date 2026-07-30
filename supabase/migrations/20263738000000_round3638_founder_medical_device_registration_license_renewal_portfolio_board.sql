-- Round 3638: Founder Medical-Device Registration / License Renewal Portfolio Board
-- MDR-2017 registration/license portfolio — device × class × license type × issue/expiry × days-to-expiry × renewal lead × dossier readiness × fee status × renewal status × trend × CAPA

-- =============================================================================
-- TABLE 1: md_license_r3638 — per-device MDR-2017 registration/license records
-- =============================================================================
create table if not exists public.md_license_r3638 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  device_name text not null,
  registration_number text not null,
  period_month date not null,
  issue_date date not null,
  expiry_date date not null,
  days_to_expiry int not null,
  renewal_lead_days int not null,
  dossier_readiness_pct numeric(5,2),
  fee_paid boolean not null,
  device_class text not null check (device_class in (
    'class_a','class_b','class_c','class_d'
  )),
  license_type text not null check (license_type in (
    'manufacturing','import','wholesale','test_license','loan_license'
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

alter table public.md_license_r3638 enable row level security;

create index if not exists idx_md_license_r3638_org on public.md_license_r3638(organization_id);
create index if not exists idx_md_license_r3638_expiry on public.md_license_r3638(expiry_date);
create index if not exists idx_md_license_r3638_status on public.md_license_r3638(renewal_status);

-- =============================================================================
-- TABLE 2: md_license_capa_actions_r3638 — CAPA & renewal follow-up actions
-- =============================================================================
create table if not exists public.md_license_capa_actions_r3638 (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.md_license_r3638(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'license_expiry_imminent','renewal_application_delayed','dossier_incomplete',
    'fee_payment_pending','device_class_reclassification','test_license_lapse',
    'import_license_gap','regulatory_query_open','labeling_noncompliance','post_market_surveillance_due'
  )),
  root_cause text not null check (root_cause in (
    'dossier_preparation_backlog','regulatory_consultant_delay','cdsco_query_pending',
    'fee_budget_not_approved','notified_body_delay','internal_documentation_gap',
    'test_report_awaited','change_in_regulation','staff_turnover','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_dossier_submission','engage_regulatory_consultant','respond_to_cdsco_query',
    'release_renewal_fee','follow_up_notified_body','complete_documentation',
    'submit_test_license_application','update_labeling','escalate_to_management','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','market_withdrawal_risk','none','internal_only',
    'iso_13485_deviation','supply_disruption_risk'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.md_license_capa_actions_r3638 enable row level security;

create index if not exists idx_md_license_capa_r3638_license on public.md_license_capa_actions_r3638(license_id);
create index if not exists idx_md_license_capa_r3638_status on public.md_license_capa_actions_r3638(capa_status);

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

  -- 16 license portfolio rows
  insert into public.md_license_r3638 (
    organization_id, device_name, registration_number, period_month, issue_date, expiry_date,
    days_to_expiry, renewal_lead_days, dossier_readiness_pct, fee_paid,
    device_class, license_type, renewal_status, trend_dir, notes
  )
  select v_org_id, q.dname, q.regno, q.pmon::date, q.idate::date, q.edate::date,
    q.dte, q.rlead, q.dossier, q.fee,
    q.dclass, q.ltype, q.rstat, q.tdir, q.nt
  from (values
    ('ICU Ventilator','MFG-VENT-2021-0455','2026-07-01','2021-08-15','2026-08-14',
     15,90,88.0,true,'class_c','manufacturing','renewal_due','worsening','MDR-2017 manufacturing licence expiring in 15 days — renewal dossier under compilation'),
    ('Volumetric Infusion Pump','MFG-INF-2021-0512','2026-07-01','2021-09-01','2027-08-31',
     397,120,72.5,true,'class_c','manufacturing','valid','stable','Licence valid — periodic PMS report on schedule'),
    ('Multipara Patient Monitor','IMP-MON-2022-0810','2026-07-01','2022-03-10','2026-09-09',
     41,90,65.0,false,'class_b','import','renewal_due','worsening','Import registration renewal fee unpaid — form MD-15 pending'),
    ('Haemodialysis Machine','MFG-DIAL-2020-0233','2026-06-01','2020-06-20','2026-06-19',
     -41,120,55.0,false,'class_c','manufacturing','expired','worsening','Manufacturing licence expired 41 days ago — production hold, urgent renewal'),
    ('Biphasic Defibrillator','IMP-DEF-2021-0677','2026-06-01','2021-11-05','2026-11-04',
     97,90,80.0,true,'class_c','import','under_renewal','improving','Renewal application filed with CDSCO — query response submitted'),
    ('Mobile C-arm Fluoroscopy','IMP-CARM-2022-0901','2026-07-01','2022-07-22','2027-07-21',
     356,120,90.0,true,'class_c','import','valid','stable','AERB and CDSCO import licence current'),
    ('Anaesthesia Workstation','MFG-ANES-2021-0344','2026-05-01','2021-05-18','2026-05-17',
     -74,120,48.0,false,'class_c','manufacturing','expired','worsening','Licence lapsed — fresh application under prep, dossier incomplete'),
    ('Syringe Infusion Pump','WHL-SYR-2023-0125','2026-07-01','2023-02-14','2028-02-13',
     563,90,95.0,true,'class_c','wholesale','valid','stable','Wholesale form MD-42 valid'),
    ('12-Lead ECG Machine','MFG-ECG-2022-0588','2026-06-01','2022-08-30','2026-08-29',
     30,90,70.0,true,'class_b','manufacturing','renewal_due','stable','Renewal due in 30 days — dossier 70 percent ready'),
    ('Ultrasound Scanner','IMP-USG-2021-0733','2026-07-01','2021-10-12','2026-10-11',
     73,90,62.0,false,'class_b','import','application_pending','worsening','Renewal application filed but CDSCO query pending, fee unpaid'),
    ('128-Slice CT Scanner','IMP-CT-2020-0199','2026-05-01','2020-04-25','2026-04-24',
     -97,120,40.0,false,'class_c','import','expired','worsening','Import registration expired — AERB NOC also under review'),
    ('Implantable Cardiac Pacemaker','IMP-PACE-2022-0455','2026-07-01','2022-01-30','2027-01-29',
     179,150,85.0,true,'class_d','import','valid','improving','Class D implant registration valid — vigilance reporting compliant'),
    ('Drug-Eluting Coronary Stent','IMP-STENT-2021-0388','2026-06-01','2021-12-01','2026-12-01',
     124,150,78.0,true,'class_d','import','under_renewal','stable','Renewal in progress with notified-body certificate awaited'),
    ('Reusable Surgical Retractor Set','MFG-RETR-2023-0077','2026-07-01','2023-04-05','2028-04-04',
     613,60,92.0,true,'class_a','manufacturing','valid','stable','Class A manufacturing licence current'),
    ('Neonatal Phototherapy Unit','TST-PHOTO-2024-0021','2026-07-01','2024-06-10','2026-08-09',
     10,45,58.0,false,'class_b','test_license','renewal_due','worsening','Test licence MD-13 expiring — commercial licence application not yet filed'),
    ('Fingertip Pulse Oximeter','LON-OXI-2023-0260','2026-06-01','2023-07-19','2026-07-18',
     -12,60,50.0,false,'class_a','loan_license','expired','worsening','Loan-licence expired — contract manufacturer registration lapsed')
  ) as q(dname, regno, pmon, idate, edate, dte, rlead, dossier, fee, dclass, ltype, rstat, tdir, nt);

  -- CAPA seed — attach to specific licenses via registration_number
  insert into public.md_license_capa_actions_r3638 (
    license_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MFG-DIAL-2020-0233','renewal_application_delayed','dossier_preparation_backlog','expedite_dossier_submission','overdue','supply_disruption_risk','Regulatory Affairs - Priya Nair','2026-07-10',null,180000.00,'Production on hold — expedite renewal dossier submission to CDSCO'),
    ('MFG-ANES-2021-0344','dossier_incomplete','internal_documentation_gap','complete_documentation','in_progress','market_withdrawal_risk','QA Head - Rajesh Kumar','2026-07-20',null,145000.00,'Device master file gaps being closed before fresh application'),
    ('IMP-CT-2020-0199','import_license_gap','cdsco_query_pending','respond_to_cdsco_query','escalated','cdsco_notifiable','Import Lead - Anita Desai','2026-07-08',null,260000.00,'AERB and CDSCO query escalated — import-cleared shipments blocked'),
    ('IMP-MON-2022-0810','fee_payment_pending','fee_budget_not_approved','release_renewal_fee','open','supply_disruption_risk','Finance - Suresh Menon','2026-07-15',null,95000.00,'Form MD-15 renewal fee awaiting budget approval'),
    ('IMP-USG-2021-0733','regulatory_query_open','regulatory_consultant_delay','engage_regulatory_consultant','in_progress','iso_13485_deviation','Regulatory Affairs - Priya Nair','2026-07-25',null,70000.00,'Consultant engaged to draft CDSCO query response'),
    ('IMP-STENT-2021-0388','renewal_application_delayed','notified_body_delay','follow_up_notified_body','open','market_withdrawal_risk','Regulatory Affairs - Meera Iyer','2026-09-30',null,210000.00,'Notified-body CE certificate renewal awaited for stent dossier'),
    ('TST-PHOTO-2024-0021','test_license_lapse','test_report_awaited','submit_test_license_application','open','internal_only','R and D - Karthik Rao','2026-08-01',null,42000.00,'Performance test report awaited before commercial licence filing'),
    ('LON-OXI-2023-0260','post_market_surveillance_due','change_in_regulation','update_labeling','closed','cdsco_notifiable','QA Head - Rajesh Kumar','2026-06-30','2026-06-28',38000.00,'Labeling updated per revised MDR schedule — loan-licence CM re-registered')
  ) as q(regno, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.md_license_r3638 e
    on e.organization_id = v_org_id and e.registration_number = q.regno;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal status distribution
create or replace function public.founder_r3638_renewal_status_rollup()
returns table(renewal_status text, licenses bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.md_license_r3638)
  select l.renewal_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.md_license_r3638 l
  group by l.renewal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_renewal_status_rollup() from public, anon;
grant execute on function public.founder_r3638_renewal_status_rollup() to authenticated;

-- 2) Device-class scorecard
create or replace function public.founder_r3638_device_class_scorecard()
returns table(
  device_class text,
  total_licenses bigint,
  valid bigint,
  renewal_due bigint,
  under_renewal bigint,
  expired bigint,
  app_pending bigint,
  fee_unpaid bigint,
  avg_dossier_readiness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class,
    count(*)::bigint,
    count(*) filter (where l.renewal_status = 'valid')::bigint,
    count(*) filter (where l.renewal_status = 'renewal_due')::bigint,
    count(*) filter (where l.renewal_status = 'under_renewal')::bigint,
    count(*) filter (where l.renewal_status = 'expired')::bigint,
    count(*) filter (where l.renewal_status = 'application_pending')::bigint,
    count(*) filter (where l.fee_paid = false)::bigint,
    round(avg(l.dossier_readiness_pct), 1)
  from public.md_license_r3638 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3638_device_class_scorecard() to authenticated;

-- 3) License-type x renewal-status matrix
create or replace function public.founder_r3638_license_type_status_matrix()
returns table(license_type text, renewal_status text, licenses bigint, avg_days_to_expiry numeric, avg_dossier_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.license_type, l.renewal_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1),
    round(avg(l.dossier_readiness_pct), 1)
  from public.md_license_r3638 l
  group by l.license_type, l.renewal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_license_type_status_matrix() from public, anon;
grant execute on function public.founder_r3638_license_type_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3638_monthly_expiry_trend()
returns table(period_month date, licenses bigint, expiring_soon bigint, expired bigint, renewal_due bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.days_to_expiry between 0 and 90)::bigint,
    count(*) filter (where l.renewal_status = 'expired')::bigint,
    count(*) filter (where l.renewal_status = 'renewal_due')::bigint,
    round(avg(l.days_to_expiry), 1)
  from public.md_license_r3638 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3638_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3638_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3638_capa_status_board()
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
  from public.md_license_capa_actions_r3638 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_capa_status_board() from public, anon;
grant execute on function public.founder_r3638_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3638_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.md_license_capa_actions_r3638)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.md_license_capa_actions_r3638 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3638_root_cause_pareto() to authenticated;

-- 7) Expiry-exposure digest (banded by days-to-expiry)
create or replace function public.founder_r3638_expiry_exposure_digest()
returns table(exposure_band text, licenses bigint, fee_unpaid bigint, renewal_action_needed bigint, avg_dossier_readiness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with banded as (
    select case
      when l.days_to_expiry < 0 then 'expired'
      when l.days_to_expiry <= 30 then 'critical_0_30'
      when l.days_to_expiry <= 90 then 'warning_31_90'
      when l.days_to_expiry <= 180 then 'watch_91_180'
      else 'safe_180_plus' end as exposure_band,
      l.fee_paid, l.dossier_readiness_pct, l.renewal_status
    from public.md_license_r3638 l
  )
  select b.exposure_band, count(*)::bigint,
    count(*) filter (where b.fee_paid = false)::bigint,
    count(*) filter (where b.renewal_status in ('renewal_due','expired','application_pending'))::bigint,
    round(avg(b.dossier_readiness_pct), 1)
  from banded b
  group by b.exposure_band
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3638_expiry_exposure_digest() from public, anon;
grant execute on function public.founder_r3638_expiry_exposure_digest() to authenticated;

-- 8) High-risk renewal queue (expired / renewal-due / at-risk)
create or replace function public.founder_r3638_high_risk_queue()
returns table(
  device_name text,
  registration_number text,
  device_class text,
  license_type text,
  expiry_date date,
  days_to_expiry int,
  renewal_status text,
  dossier_readiness_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.registration_number, l.device_class, l.license_type,
    l.expiry_date, l.days_to_expiry, l.renewal_status, l.dossier_readiness_pct, l.notes
  from public.md_license_r3638 l
  where l.renewal_status in ('expired','renewal_due','application_pending')
     or l.days_to_expiry <= 30
     or l.fee_paid = false
     or l.dossier_readiness_pct < 60
     or l.trend_dir = 'worsening'
  order by l.days_to_expiry asc, l.device_name;
end;
$$;

revoke execute on function public.founder_r3638_high_risk_queue() from public, anon;
grant execute on function public.founder_r3638_high_risk_queue() to authenticated;
