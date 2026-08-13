-- Round 3739: Founder IEC / DGFT Import-Export Licensing Compliance Board
-- Company Importer-Exporter Code (IEC) and DGFT registration/scheme compliance -- IEC validity,
-- RCMC/scheme registrations, annual return filing, shipment-level usage errors.
-- Distinct from any medical-device-import-license-registration page, which is CDSCO PRODUCT-specific
-- import licensing by OEM/license-form, not the company's general trade code/scheme registrations.

-- =============================================================================
-- TABLE 1: iec_dgft_r3739 -- IEC/DGFT registration & scheme compliance facts
-- =============================================================================
create table if not exists public.iec_dgft_r3739 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  registration_type text not null,
  authority text not null,
  period_month date not null,
  registration_number text,
  issue_date date,
  expiry_date date,
  days_to_expiry int,
  annual_return_filed boolean not null,
  shipments_processed int,
  iec_usage_errors int,
  scheme_benefit_claimed_rupees numeric(12,2),
  kyc_updated boolean not null,
  reg_class text not null check (reg_class in (
    'iec_code','rcmc_registration','export_promotion_scheme','advance_authorization','epcg_license'
  )),
  compliance_status text not null check (compliance_status in (
    'active_compliant','renewal_due','return_overdue','usage_error_flagged','suspended'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iec_dgft_r3739 enable row level security;

create index if not exists idx_iec_dgft_r3739_org on public.iec_dgft_r3739(organization_id);
create index if not exists idx_iec_dgft_r3739_month on public.iec_dgft_r3739(period_month);
create index if not exists idx_iec_dgft_r3739_status on public.iec_dgft_r3739(compliance_status);

-- =============================================================================
-- TABLE 2: iec_dgft_capa_actions_r3739 -- CAPA for licensing/scheme compliance gaps
-- =============================================================================
create table if not exists public.iec_dgft_capa_actions_r3739 (
  id uuid primary key default gen_random_uuid(),
  iec_dgft_id uuid references public.iec_dgft_r3739(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iec_dgft_capa_actions_r3739 enable row level security;

create index if not exists idx_iec_dgft_capa_r3739_reg on public.iec_dgft_capa_actions_r3739(iec_dgft_id);
create index if not exists idx_iec_dgft_capa_r3739_status on public.iec_dgft_capa_actions_r3739(capa_status);

-- =============================================================================
-- SEED DATA -- reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 IEC/DGFT registration & scheme rows
  insert into public.iec_dgft_r3739 (
    organization_id, registration_type, authority, period_month, registration_number,
    issue_date, expiry_date, days_to_expiry, annual_return_filed, shipments_processed,
    iec_usage_errors, scheme_benefit_claimed_rupees, kyc_updated, reg_class, compliance_status,
    trend_dir, notes
  )
  select v_org_id, q.rt, q.au, q.pm::date, q.rn,
    q.isd::date, q.exd::date, q.dte::int, q.arf, q.shp::int,
    q.err::int, q.sbr::numeric, q.kyc, q.rc, q.cst,
    q.trd, q.nt
  from (values
    ('Importer-Exporter Code (IEC)','DGFT Regional Authority - Mumbai','2026-07-01','IEC-MUM-0417822',
     '2018-04-12',null,null,true,142,
     0,null,true,'iec_code','active_compliant','stable','Annual IEC KYC updation completed in April; no shipping-bill mismatches this cycle'),
    ('Importer-Exporter Code (IEC)','DGFT Regional Authority - Delhi','2026-07-01','IEC-DEL-0398215',
     '2016-08-03',null,null,false,88,
     3,null,false,'iec_code','usage_error_flagged','worsening','KYC updation overdue since June; 3 shipping-bill AD-code mismatches flagged by ICEGATE'),
    ('Importer-Exporter Code (IEC)','DGFT Regional Authority - Chennai','2026-06-01','IEC-CHE-0512090',
     '2020-01-22',null,null,true,61,
     0,null,true,'iec_code','active_compliant','stable','Branch-office IEC - usage clean across all export shipments this cycle'),
    ('Importer-Exporter Code (IEC) - Annual Updation','DGFT Regional Authority - Bengaluru','2026-05-01','IEC-BLR-0473311',
     '2015-11-09',null,null,false,34,
     1,null,false,'iec_code','return_overdue','worsening','Mandatory April-June annual updation window missed; IEC deactivation risk flagged by DGFT portal'),
    ('RCMC - Engineering Goods Export','EEPC India (Engineering Export Promotion Council)','2026-07-01','RCMC-EEPC-22841',
     '2023-06-01','2026-05-31',-41,true,0,
     0,null,true,'rcmc_registration','renewal_due','worsening','RCMC validity lapsed 31-May; renewal application submitted, EEPC processing pending'),
    ('RCMC - Merchandise Exporters','FIEO (Federation of Indian Export Organisations)','2026-07-01','RCMC-FIEO-30567',
     '2024-04-15','2027-04-14',622,true,0,
     0,null,true,'rcmc_registration','active_compliant','stable','FIEO membership current; no compliance gaps this cycle'),
    ('RCMC - Leather & Allied Products','Council for Leather Exports','2026-06-01','RCMC-CLE-11209',
     '2021-09-10','2026-04-15',-47,false,0,
     0,null,false,'rcmc_registration','suspended','worsening','RCMC suspended by council for non-submission of export performance report two cycles running'),
    ('Export Promotion Scheme - RoDTEP Registration','DGFT Regional Authority - Mumbai','2026-07-01','EPS-ROD-MUM-8841',
     '2022-01-01',null,null,true,76,
     0,1842000.00,true,'export_promotion_scheme','active_compliant','improving','RoDTEP scrips claimed against all eligible shipping bills; e-scrip ledger reconciled monthly'),
    ('Export Promotion Scheme - RoSCTL Registration','DGFT Regional Authority - Pune','2026-06-01','EPS-ROS-PUN-5523',
     '2022-03-18',null,null,true,42,
     4,615000.00,true,'export_promotion_scheme','usage_error_flagged','worsening','4 shipping bills claimed under wrong RoSCTL rate slab; refund recovery notice received from customs'),
    ('Export Promotion Scheme - MEIS Legacy Claim','DGFT Regional Authority - Delhi','2026-05-01','EPS-MEIS-DEL-2290',
     '2019-07-01','2026-03-31',-88,false,0,
     0,328000.00,true,'export_promotion_scheme','return_overdue','worsening','Legacy MEIS scrip utilisation return overdue; DGFT closure certificate pending submission'),
    ('Advance Authorization License - Import of Raw Materials','DGFT Regional Authority - Chennai','2026-07-01','AA-CHE-77042',
     '2025-08-20','2026-08-19',11,true,18,
     0,4120000.00,true,'advance_authorization','active_compliant','stable','Export obligation 92% fulfilled against 24-month EO period; on track for closure'),
    ('Advance Authorization License - Duty-Free Component Import','DGFT Regional Authority - Bengaluru','2026-07-01','AA-BLR-65118',
     '2024-06-05','2026-06-04',-35,true,9,
     1,2860000.00,true,'advance_authorization','renewal_due','worsening','EO period lapsed with 71% fulfilment; EODC extension application filed with regional authority'),
    ('Advance Authorization License - Bulk Input Import','DGFT Regional Authority - Mumbai','2026-06-01','AA-MUM-58873',
     '2023-11-12','2025-11-11',-232,false,3,
     2,970000.00,false,'advance_authorization','suspended','worsening','License suspended for export-obligation default; bank guarantee invoked, EODC regularisation pending'),
    ('EPCG License - Capital Goods Import','DGFT Regional Authority - Delhi','2026-07-01','EPCG-DEL-40291',
     '2022-02-14','2028-02-13',566,true,22,
     0,6540000.00,true,'epcg_license','active_compliant','stable','Block-wise export obligation on schedule; installation certificate filed within stipulated 6 months'),
    ('EPCG License - Testing Equipment Import','DGFT Regional Authority - Pune','2026-06-01','EPCG-PUN-38105',
     '2021-10-30','2027-10-29',856,true,14,
     2,3120000.00,true,'epcg_license','usage_error_flagged','worsening','2 shipping bills omitted EPCG authorisation number reference; export obligation shortfall alert raised'),
    ('EPCG License - Workshop Machinery Import','DGFT Regional Authority - Chennai','2026-05-01','EPCG-CHE-29477',
     '2020-05-18','2026-05-17',-84,false,6,
     0,1980000.00,false,'epcg_license','renewal_due','worsening','Block-1 EO period closed with annual return not yet filed; installation certificate follow-up needed')
  ) as q(rt, au, pm, rn, isd, exd, dte, arf, shp, err, sbr, kyc, rc, cst, trd, nt);

  -- 8 CAPA rows -- attach to registrations via registration_number
  insert into public.iec_dgft_capa_actions_r3739 (
    iec_dgft_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('IEC-DEL-0398215','AD code mismatch not validated before shipping bill filing','Enforce AD-code cross-check in export documentation checklist before filing','in_progress','Trade Compliance Manager','2026-08-25',null,'Freight forwarder briefed on updated AD-code SOP; two shipments corrected via amendment'),
    ('IEC-BLR-0473311','Annual IEC updation window missed due to no calendar reminder','File pending IEC annual updation immediately and add DGFT compliance calendar','open','Compliance Officer','2026-08-20',null,'Deactivation notice received from DGFT portal; filing in progress via digital signature'),
    ('RCMC-EEPC-22841','RCMC renewal application submitted late, past validity date','Expedite EEPC renewal follow-up and pre-file 90 days before future expiry','in_progress','Export Documentation Lead','2026-08-30',null,'EEPC has acknowledged application; certificate expected within 3 weeks'),
    ('RCMC-CLE-11209','Export performance report not filed for two consecutive half-years','Submit backlog export performance reports and request suspension revocation','overdue','Export Documentation Lead','2026-07-31',null,'Council requires both pending reports before reinstating membership; data compilation ongoing'),
    ('EPS-ROS-PUN-5523','Incorrect RoSCTL rate slab applied at shipping-bill filing stage','Correct rate slab mapping in export ERP and file supplementary claims','open','Finance - Export Incentives','2026-08-28',null,'Customs recovery notice under response; rate-slab master data corrected in ERP'),
    ('EPS-MEIS-DEL-2290','Legacy MEIS closure certificate never filed after scheme sunset','Compile utilisation records and submit DGFT closure certificate','in_progress','Trade Compliance Manager','2026-09-10',null,'Old scrip records retrieved from archive; certificate draft under internal review'),
    ('AA-BLR-65118','Export obligation period lapsed with 71% fulfilment due to raw-material delay','File EODC extension request with regularisation fee','open','Trade Compliance Manager','2026-09-05',null,'Extension request drafted; regularisation fee calculation pending finance sign-off'),
    ('AA-MUM-58873','Export obligation default led to bank guarantee invocation and license suspension','Regularise EODC via composition fee and request suspension lift','overdue','Head of Trade Compliance','2026-07-20',null,'Composition-fee computation with customs in progress; suspension remains active')
  ) as q(rn, rc, ca, cst, ownr, tcd, acd, nt)
  join public.iec_dgft_r3739 e
    on e.organization_id = v_org_id and e.registration_number = q.rn;
end;
$seed$;

-- =============================================================================
-- RPCs -- 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3739_compliance_status_rollup()
returns table(compliance_status text, registrations bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iec_dgft_r3739)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.iec_dgft_r3739 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3739_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3739_compliance_status_rollup() to authenticated;

-- 2) Authority scorecard
create or replace function public.founder_r3739_authority_scorecard()
returns table(
  authority text,
  registrations bigint,
  active_compliant bigint,
  renewal_due bigint,
  return_overdue bigint,
  usage_error_flagged bigint,
  suspended bigint,
  total_usage_errors bigint,
  total_scheme_benefit_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.authority,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'active_compliant')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'return_overdue')::bigint,
    count(*) filter (where l.compliance_status = 'usage_error_flagged')::bigint,
    count(*) filter (where l.compliance_status = 'suspended')::bigint,
    coalesce(sum(l.iec_usage_errors),0)::bigint,
    coalesce(sum(l.scheme_benefit_claimed_rupees),0)::numeric
  from public.iec_dgft_r3739 l
  group by l.authority
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3739_authority_scorecard() from public, anon;
grant execute on function public.founder_r3739_authority_scorecard() to authenticated;

-- 3) Reg-class x compliance-status matrix
create or replace function public.founder_r3739_reg_class_status_matrix()
returns table(reg_class text, compliance_status text, registrations bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reg_class, l.compliance_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1)
  from public.iec_dgft_r3739 l
  group by l.reg_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3739_reg_class_status_matrix() from public, anon;
grant execute on function public.founder_r3739_reg_class_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3739_monthly_expiry_trend()
returns table(
  period_month date,
  registrations bigint,
  expiring_soon bigint,
  overdue_returns bigint,
  avg_days_to_expiry numeric,
  worsening_registrations bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.days_to_expiry is not null and l.days_to_expiry >= 0 and l.days_to_expiry <= 60)::bigint,
    count(*) filter (where l.annual_return_filed = false)::bigint,
    round(avg(l.days_to_expiry), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.iec_dgft_r3739 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3739_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3739_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3739_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.iec_dgft_capa_actions_r3739 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3739_capa_status_board() from public, anon;
grant execute on function public.founder_r3739_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3739_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iec_dgft_capa_actions_r3739)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.iec_dgft_capa_actions_r3739 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3739_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3739_root_cause_pareto() to authenticated;

-- 7) Usage-error digest by reg-class
create or replace function public.founder_r3739_usage_error_digest()
returns table(
  reg_class text,
  registrations bigint,
  flagged_registrations bigint,
  total_usage_errors bigint,
  total_shipments_processed bigint,
  error_rate_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reg_class,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'usage_error_flagged')::bigint,
    coalesce(sum(l.iec_usage_errors),0)::bigint,
    coalesce(sum(l.shipments_processed),0)::bigint,
    round(coalesce(sum(l.iec_usage_errors),0)::numeric / nullif(coalesce(sum(l.shipments_processed),0),0) * 100.0, 2)
  from public.iec_dgft_r3739 l
  where l.iec_usage_errors > 0 or l.compliance_status = 'usage_error_flagged'
  group by l.reg_class
  order by coalesce(sum(l.iec_usage_errors),0) desc;
end;
$$;

revoke all on function public.founder_r3739_usage_error_digest() from public, anon;
grant execute on function public.founder_r3739_usage_error_digest() to authenticated;

-- 8) High-risk queue (suspended / return overdue registrations, worst first)
create or replace function public.founder_r3739_high_risk_queue()
returns table(
  registration_type text,
  authority text,
  registration_number text,
  reg_class text,
  compliance_status text,
  period_month date,
  days_to_expiry int,
  iec_usage_errors int,
  annual_return_filed boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.registration_type, l.authority, l.registration_number, l.reg_class,
    l.compliance_status, l.period_month, l.days_to_expiry, l.iec_usage_errors,
    l.annual_return_filed, l.notes
  from public.iec_dgft_r3739 l
  where l.compliance_status in ('suspended','return_overdue')
  order by l.days_to_expiry asc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3739_high_risk_queue() from public, anon;
grant execute on function public.founder_r3739_high_risk_queue() to authenticated;
