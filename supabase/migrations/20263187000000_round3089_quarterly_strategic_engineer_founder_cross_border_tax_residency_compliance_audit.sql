-- Round 3089: Founder Quarterly Strategic Engineer-Founder Cross-Border Tax-Residency Compliance Audit
-- Tracks engineer/founder tax-residency status across jurisdictions, days-of-presence, treaty positions,
-- and quarterly compliance audit findings for cross-border tax exposure.

create table if not exists engineer_tax_residency_profiles_r3089 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_label text not null,
  primary_jurisdiction text not null check (primary_jurisdiction in ('IN','US','GB','AE','SG','CA','AU','DE','NL')),
  secondary_jurisdiction text check (secondary_jurisdiction in ('IN','US','GB','AE','SG','CA','AU','DE','NL')),
  residency_status text not null check (residency_status in ('resident','non_resident','rnor','dual_resident','deemed_resident')),
  days_present_primary int not null check (days_present_primary between 0 and 366),
  days_present_secondary int check (days_present_secondary between 0 and 366),
  treaty_tiebreaker_position text check (treaty_tiebreaker_position in ('permanent_home','centre_of_vital_interests','habitual_abode','nationality','mutual_agreement','not_applicable')),
  pe_risk_level text not null check (pe_risk_level in ('none','low','moderate','high','critical')),
  audit_quarter text not null check (audit_quarter in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  notes text
);

alter table engineer_tax_residency_profiles_r3089 enable row level security;

drop policy if exists tax_res_prof_founder_r3089 on engineer_tax_residency_profiles_r3089;
create policy tax_res_prof_founder_r3089 on engineer_tax_residency_profiles_r3089
  for select using (is_founder());

create table if not exists cross_border_compliance_findings_r3089 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  profile_id uuid references engineer_tax_residency_profiles_r3089(id) on delete cascade,
  finding_category text not null check (finding_category in ('pe_exposure','withholding','transfer_pricing','social_security','equity_comp','fbar','crs_reporting','treaty_claim','documentation')),
  severity text not null check (severity in ('info','low','medium','high','critical')),
  status text not null check (status in ('open','in_review','remediated','accepted_risk','escalated')),
  finding_title text not null,
  estimated_exposure_usd numeric(14,2),
  remediation_owner text check (remediation_owner in ('tax_advisor','founder','engineer','controller','external_counsel')),
  due_date date,
  closed_at timestamptz
);

alter table cross_border_compliance_findings_r3089 enable row level security;

drop policy if exists cb_findings_founder_r3089 on cross_border_compliance_findings_r3089;
create policy cb_findings_founder_r3089 on cross_border_compliance_findings_r3089
  for select using (is_founder());

-- Seeds: tax residency profiles
insert into engineer_tax_residency_profiles_r3089
  (engineer_label, primary_jurisdiction, secondary_jurisdiction, residency_status, days_present_primary, days_present_secondary, treaty_tiebreaker_position, pe_risk_level, audit_quarter, notes)
values
  ('ENG-001 Senior Founder', 'IN', 'US', 'resident', 210, 95, 'permanent_home', 'moderate', '2026-Q2', 'CEO splits time between Hyderabad and SF'),
  ('ENG-002 CTO', 'IN', 'SG', 'rnor', 175, 120, 'centre_of_vital_interests', 'high', '2026-Q2', 'RNOR window expiring 2026-Q4'),
  ('ENG-003 Lead Eng', 'IN', null, 'resident', 365, null, 'not_applicable', 'none', '2026-Q2', 'Pure domestic'),
  ('ENG-004 Field Eng UAE', 'AE', 'IN', 'non_resident', 280, 85, 'permanent_home', 'low', '2026-Q2', 'Dubai service-engineer rotation'),
  ('ENG-005 Remote US Contractor', 'US', 'IN', 'resident', 220, 60, 'nationality', 'critical', '2026-Q2', 'Possible PE trigger via fixed laptop'),
  ('ENG-006 DevOps SG', 'SG', 'IN', 'resident', 240, 90, 'habitual_abode', 'moderate', '2026-Q2', 'EP holder Singapore'),
  ('ENG-007 UK Sales Eng', 'GB', 'IN', 'resident', 195, 110, 'centre_of_vital_interests', 'high', '2026-Q2', 'UK statutory residence test borderline'),
  ('ENG-008 CA Remote', 'CA', 'IN', 'dual_resident', 180, 180, 'mutual_agreement', 'critical', '2026-Q2', 'MAP filing pending CRA-CBDT'),
  ('ENG-009 AU Frontier', 'AU', 'IN', 'non_resident', 305, 45, 'permanent_home', 'low', '2026-Q2', 'AU 183-day rule applied'),
  ('ENG-010 DE Berlin', 'DE', 'IN', 'resident', 250, 70, 'habitual_abode', 'moderate', '2026-Q2', 'German wage tax registered'),
  ('ENG-011 NL Rotterdam', 'NL', 'IN', 'resident', 230, 80, 'centre_of_vital_interests', 'high', '2026-Q2', '30% ruling claim under review'),
  ('ENG-012 IN-US deemed', 'IN', 'US', 'deemed_resident', 119, 200, 'permanent_home', 'critical', '2026-Q2', 'Sec 6(1A) Indian deemed-resident trigger'),
  ('ENG-013 Q1 baseline', 'IN', null, 'resident', 360, null, 'not_applicable', 'none', '2026-Q1', 'Q1 reference baseline'),
  ('ENG-014 Q3 forecast', 'IN', 'US', 'rnor', 165, 130, 'mutual_agreement', 'high', '2026-Q3', 'Projected Q3 dual exposure'),
  ('ENG-015 Q4 forecast', 'IN', 'AE', 'resident', 290, 50, 'permanent_home', 'low', '2026-Q4', 'Year-end reconciliation forecast');

-- Seeds: compliance findings
insert into cross_border_compliance_findings_r3089
  (profile_id, finding_category, severity, status, finding_title, estimated_exposure_usd, remediation_owner, due_date, closed_at)
values
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-001 Senior Founder'), 'pe_exposure', 'high', 'in_review', 'Founder US presence may create PE for IN entity', 145000.00, 'external_counsel', '2026-07-31'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-002 CTO'), 'treaty_claim', 'medium', 'open', 'RNOR claim documentation incomplete', 32000.00, 'tax_advisor', '2026-08-15'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-005 Remote US Contractor'), 'pe_exposure', 'critical', 'escalated', 'Fixed place of business via home office in CA', 410000.00, 'external_counsel', '2026-07-15'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-005 Remote US Contractor'), 'withholding', 'high', 'open', '24% backup withholding not applied on Form W-9 absence', 58000.00, 'controller', '2026-07-20'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-007 UK Sales Eng'), 'transfer_pricing', 'high', 'in_review', 'Cost-plus markup below UK arm-length range', 87000.00, 'tax_advisor', '2026-09-01'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-008 CA Remote'), 'treaty_claim', 'critical', 'escalated', 'Dual residence — MAP filing required', 220000.00, 'external_counsel', '2026-07-30'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-006 DevOps SG'), 'social_security', 'medium', 'remediated', 'CPF vs EPF coordination resolved via COC', 12000.00, 'controller', '2026-06-01'::date, '2026-06-10T12:00:00+05:30'::timestamptz),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-010 DE Berlin'), 'equity_comp', 'high', 'open', 'ESOP vesting straddles DE residency change', 95000.00, 'tax_advisor', '2026-08-31'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-011 NL Rotterdam'), 'documentation', 'medium', 'in_review', '30% ruling supporting docs missing', 18000.00, 'engineer', '2026-08-10'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-012 IN-US deemed'), 'fbar', 'high', 'open', 'FBAR filing past due — IN-held accounts', 75000.00, 'tax_advisor', '2026-07-25'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-012 IN-US deemed'), 'crs_reporting', 'medium', 'open', 'CRS schedule incomplete for US brokerage', 22000.00, 'controller', '2026-08-20'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-004 Field Eng UAE'), 'social_security', 'low', 'accepted_risk', 'No India-UAE totalization — accepted', 4000.00, 'founder', '2026-09-30'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-009 AU Frontier'), 'withholding', 'low', 'remediated', 'AU TFN provided — withholding normalized', 2500.00, 'controller', '2026-05-15'::date, '2026-05-20T09:00:00+05:30'::timestamptz),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-001 Senior Founder'), 'equity_comp', 'medium', 'in_review', 'Founder SAR exercise straddles 2 jurisdictions', 68000.00, 'tax_advisor', '2026-08-25'::date, null),
  ((select id from engineer_tax_residency_profiles_r3089 where engineer_label = 'ENG-014 Q3 forecast'), 'pe_exposure', 'info', 'open', 'Forecast finding — model only', null, 'tax_advisor', '2026-10-01'::date, null);

revoke all on engineer_tax_residency_profiles_r3089 from public, anon;
revoke all on cross_border_compliance_findings_r3089 from public, anon;
grant select on engineer_tax_residency_profiles_r3089 to authenticated;
grant select on cross_border_compliance_findings_r3089 to authenticated;

-- RPC 1: residency profile summary
create or replace function get_tax_residency_summary_r3089()
returns table(
  audit_quarter text,
  total_profiles int,
  dual_or_deemed int,
  high_pe_risk int,
  avg_days_primary numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.audit_quarter,
    count(*)::int,
    (count(*) filter (where p.residency_status in ('dual_resident','deemed_resident')))::int,
    (count(*) filter (where p.pe_risk_level in ('high','critical')))::int,
    round(avg(p.days_present_primary)::numeric, 1)
  from engineer_tax_residency_profiles_r3089 p
  group by p.audit_quarter
  order by p.audit_quarter;
end;
$$;

revoke all on function get_tax_residency_summary_r3089() from public, anon;
grant execute on function get_tax_residency_summary_r3089() to authenticated;

-- RPC 2: jurisdiction concentration
create or replace function get_jurisdiction_concentration_r3089()
returns table(
  jurisdiction text,
  engineer_count int,
  high_risk_count int,
  total_days_present bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.primary_jurisdiction,
    count(*)::int,
    (count(*) filter (where p.pe_risk_level in ('high','critical')))::int,
    sum(p.days_present_primary)::bigint
  from engineer_tax_residency_profiles_r3089 p
  group by p.primary_jurisdiction
  order by count(*) desc;
end;
$$;

revoke all on function get_jurisdiction_concentration_r3089() from public, anon;
grant execute on function get_jurisdiction_concentration_r3089() to authenticated;

-- RPC 3: open findings by category
create or replace function get_findings_by_category_r3089()
returns table(
  finding_category text,
  open_count int,
  critical_count int,
  total_exposure_usd numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    f.finding_category,
    (count(*) filter (where f.status in ('open','in_review','escalated')))::int,
    (count(*) filter (where f.severity = 'critical'))::int,
    coalesce(sum(f.estimated_exposure_usd) filter (where f.status in ('open','in_review','escalated')), 0)::numeric
  from cross_border_compliance_findings_r3089 f
  group by f.finding_category
  order by coalesce(sum(f.estimated_exposure_usd) filter (where f.status in ('open','in_review','escalated')), 0) desc;
end;
$$;

revoke all on function get_findings_by_category_r3089() from public, anon;
grant execute on function get_findings_by_category_r3089() to authenticated;

-- RPC 4: critical findings list
create or replace function get_critical_findings_r3089()
returns table(
  engineer_label text,
  finding_title text,
  severity text,
  status text,
  estimated_exposure_usd numeric,
  due_date date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.engineer_label,
    f.finding_title,
    f.severity,
    f.status,
    f.estimated_exposure_usd,
    f.due_date
  from cross_border_compliance_findings_r3089 f
  join engineer_tax_residency_profiles_r3089 p on p.id = f.profile_id
  where f.severity in ('high','critical')
  order by f.severity desc, f.estimated_exposure_usd desc nulls last;
end;
$$;

revoke all on function get_critical_findings_r3089() from public, anon;
grant execute on function get_critical_findings_r3089() to authenticated;

-- RPC 5: remediation ownership load
create or replace function get_remediation_ownership_r3089()
returns table(
  remediation_owner text,
  open_findings int,
  total_exposure_usd numeric,
  earliest_due date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    coalesce(f.remediation_owner, 'unassigned'),
    (count(*) filter (where f.status in ('open','in_review','escalated')))::int,
    coalesce(sum(f.estimated_exposure_usd) filter (where f.status in ('open','in_review','escalated')), 0)::numeric,
    min(f.due_date) filter (where f.status in ('open','in_review','escalated'))
  from cross_border_compliance_findings_r3089 f
  group by f.remediation_owner
  order by coalesce(sum(f.estimated_exposure_usd) filter (where f.status in ('open','in_review','escalated')), 0) desc;
end;
$$;

revoke all on function get_remediation_ownership_r3089() from public, anon;
grant execute on function get_remediation_ownership_r3089() to authenticated;

-- RPC 6: treaty position breakdown
create or replace function get_treaty_position_breakdown_r3089()
returns table(
  treaty_tiebreaker_position text,
  profile_count int,
  high_pe_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    coalesce(p.treaty_tiebreaker_position, 'unspecified'),
    count(*)::int,
    (count(*) filter (where p.pe_risk_level in ('high','critical')))::int
  from engineer_tax_residency_profiles_r3089 p
  group by p.treaty_tiebreaker_position
  order by count(*) desc;
end;
$$;

revoke all on function get_treaty_position_breakdown_r3089() from public, anon;
grant execute on function get_treaty_position_breakdown_r3089() to authenticated;

-- RPC 7: quarterly burndown
create or replace function get_quarterly_burndown_r3089()
returns table(
  audit_quarter text,
  total_findings int,
  closed_findings int,
  open_exposure_usd numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.audit_quarter,
    count(f.id)::int,
    (count(*) filter (where f.status = 'remediated'))::int,
    coalesce(sum(f.estimated_exposure_usd) filter (where f.status in ('open','in_review','escalated')), 0)::numeric
  from engineer_tax_residency_profiles_r3089 p
  left join cross_border_compliance_findings_r3089 f on f.profile_id = p.id
  group by p.audit_quarter
  order by p.audit_quarter;
end;
$$;

revoke all on function get_quarterly_burndown_r3089() from public, anon;
grant execute on function get_quarterly_burndown_r3089() to authenticated;
