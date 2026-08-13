-- Round 3742: Founder Housekeeping / Pest-Control AMC Compliance Board
-- Own-premises housekeeping and pest-control AMC compliance per site — visit frequency vs
-- contracted, service-quality audit scores, chemical compliance, contract renewal status.

-- =============================================================================
-- TABLE 1: hk_pest_amc_r3742 — per-site housekeeping/pest-control AMC compliance facts
-- =============================================================================
create table if not exists public.hk_pest_amc_r3742 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  service_type text not null,
  period_month date not null,
  visits_contracted int not null,
  visits_completed int not null,
  visit_compliance_pct numeric,
  audit_score numeric,
  chemical_compliance_verified boolean not null,
  pest_incidents_reported int,
  contract_value_rupees numeric(12,2),
  contract_expiry_date date,
  vendor_name text,
  service_class text not null check (service_class in (
    'housekeeping_daily','deep_cleaning','pest_control_general','pest_control_fumigation','washroom_hygiene'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','minor_gap','visit_shortfall','quality_issue','contract_expiring'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hk_pest_amc_r3742 enable row level security;

create index if not exists idx_hk_pest_amc_r3742_org on public.hk_pest_amc_r3742(organization_id);
create index if not exists idx_hk_pest_amc_r3742_month on public.hk_pest_amc_r3742(period_month);
create index if not exists idx_hk_pest_amc_r3742_status on public.hk_pest_amc_r3742(compliance_status);

-- =============================================================================
-- TABLE 2: hk_pest_amc_capa_actions_r3742 — CAPA for housekeeping/pest-control gaps
-- =============================================================================
create table if not exists public.hk_pest_amc_capa_actions_r3742 (
  id uuid primary key default gen_random_uuid(),
  amc_id uuid references public.hk_pest_amc_r3742(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hk_pest_amc_capa_actions_r3742 enable row level security;

create index if not exists idx_hk_pest_amc_capa_r3742_amc on public.hk_pest_amc_capa_actions_r3742(amc_id);
create index if not exists idx_hk_pest_amc_capa_r3742_status on public.hk_pest_amc_capa_actions_r3742(capa_status);

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

  -- 16 housekeeping / pest-control AMC compliance rows
  insert into public.hk_pest_amc_r3742 (
    organization_id, site_name, service_type, period_month, visits_contracted,
    visits_completed, visit_compliance_pct, audit_score, chemical_compliance_verified,
    pest_incidents_reported, contract_value_rupees, contract_expiry_date, vendor_name,
    service_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.sn, q.sty, q.pm::date, q.vcn,
    q.vcm, q.vcp, q.ads, q.ccv,
    q.pir, q.cvr, q.ced::date, q.vnd,
    q.scl, q.cst, q.trd, q.nt
  from (values
    ('Bhiwandi Warehouse','Daily Housekeeping - 3 Shift Sweep & Mop','2026-07-01',30,30,100.0,92.5,true,0,480000.00,'2027-03-31','CleanEdge Facility Services','housekeeping_daily','compliant','stable','Daily sweep and mop schedule held across all three shifts; zero missed visits this month'),
    ('Chakan Plant','Quarterly Deep Clean - Shopfloor & Canteen','2026-07-01',4,4,100.0,88.0,true,0,220000.00,'2026-12-31','Sodexo FM Solutions','deep_cleaning','compliant','improving','Quarterly deep-clean of shopfloor and canteen completed ahead of scheduled audit'),
    ('Sriperumbudur Yard','General Pest Control - Rodent & Insect','2026-07-01',2,2,100.0,85.0,true,1,96000.00,'2026-09-30','Rentokil PCI','pest_control_general','minor_gap','stable','One rodent sighting near loading dock logged; bait stations replenished same day'),
    ('Manesar Hub','Godown Fumigation - Annual','2026-06-01',1,1,100.0,90.0,true,0,145000.00,'2026-08-20','PestShield India','pest_control_fumigation','contract_expiring','stable','Annual godown fumigation completed; AMC renewal quote awaited before contract expiry'),
    ('Hoskote Depot','Washroom Hygiene - Consumables & Sanitation','2026-07-01',30,28,93.3,78.0,true,0,156000.00,'2027-01-31','ISS Facility Services','washroom_hygiene','minor_gap','worsening','Two visits missed over the weekend due to vendor staff shortage'),
    ('Bhiwadi Warehouse','Daily Housekeeping - Floor & Common Area','2026-06-01',30,21,70.0,61.0,false,2,468000.00,'2026-10-15','CleanEdge Facility Services','housekeeping_daily','visit_shortfall','worsening','Nine visits skipped after vendor lost two staff to attrition; chemical usage log not maintained'),
    ('Taloja Yard','Quarterly Deep Clean - Warehouse Racking','2026-06-01',4,2,50.0,55.0,true,0,210000.00,'2026-11-30','Sodexo FM Solutions','deep_cleaning','visit_shortfall','worsening','Two scheduled deep-clean visits deferred due to monsoon flooding access issues'),
    ('Kolkata Branch Office','General Pest Control - Cockroach & Ant','2026-07-01',2,2,100.0,40.0,true,4,84000.00,'2026-12-15','Domestic Pest Solutions','pest_control_general','quality_issue','worsening','Recurring cockroach complaints from staff despite visits completed; treatment efficacy under review'),
    ('Whitefield Tech Park','Washroom Hygiene - Automated Dispensers','2026-07-01',30,30,100.0,95.0,true,0,216000.00,'2027-05-31','ISS Facility Services','washroom_hygiene','compliant','improving','Consistently top-scoring site; automated dispenser refills tracked via facilities app'),
    ('Okhla Depot','Godown Fumigation - Half Yearly','2026-05-01',1,0,0.0,null,false,3,132000.00,'2026-08-31','PestShield India','pest_control_fumigation','visit_shortfall','worsening','Scheduled fumigation missed twice; vendor cited staff unavailability while pest sightings rise'),
    ('Ranchi Branch','Daily Housekeeping - Office & Pantry','2026-06-01',30,29,96.7,84.0,true,0,360000.00,'2027-02-28','Urban Facility Management','housekeeping_daily','compliant','stable','One visit rescheduled for a public holiday; otherwise fully on track'),
    ('Guwahati Hub','General Pest Control - Termite & Rodent','2026-06-01',2,2,100.0,89.0,true,0,78000.00,'2026-08-25','Rentokil PCI','pest_control_general','contract_expiring','stable','AMC renewal due within thirty days; vendor performance satisfactory and renewal recommended'),
    ('Indore Warehouse','Quarterly Deep Clean - Loading Bay','2026-07-01',4,4,100.0,91.5,true,0,198000.00,'2027-01-15','Sodexo FM Solutions','deep_cleaning','compliant','improving','Deep-clean audit score improved after retraining vendor crew on SOP checklist'),
    ('Nashik Depot','Washroom Hygiene - Consumables & Sanitation','2026-06-01',30,24,80.0,68.0,true,0,144000.00,'2026-09-10','ISS Facility Services','washroom_hygiene','quality_issue','worsening','Supply audit found dispenser refills running low mid-week despite visit logs marked complete'),
    ('Coimbatore Yard','Godown Fumigation - Half Yearly','2026-07-01',1,1,100.0,93.0,true,0,128000.00,'2027-04-30','PestShield India','pest_control_fumigation','compliant','stable','Half-yearly fumigation completed with chemical usage log verified against MSDS records'),
    ('Vizag Port Office','Daily Housekeeping - Office & Cafeteria','2026-05-01',30,26,86.7,72.0,true,1,312000.00,'2026-08-05','CleanEdge Facility Services','housekeeping_daily','contract_expiring','stable','AMC expires within fifteen days; renewal negotiation in progress with incumbent vendor')
  ) as q(sn, sty, pm, vcn, vcm, vcp, ads, ccv, pir, cvr, ced, vnd, scl, cst, trd, nt);

  -- 8 CAPA rows — attach to AMC rows via site_name
  insert into public.hk_pest_amc_capa_actions_r3742 (
    amc_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Sriperumbudur Yard','Bait station coverage gap near loading dock','Add two additional bait stations and increase inspection frequency to weekly','in_progress','Facilities Manager - South','2026-08-25',null,'Vendor conducting supplementary inspection this week; no further sightings reported since'),
    ('Hoskote Depot','Vendor weekend staffing shortage','Vendor to maintain a backup roster for weekend washroom-hygiene coverage','open','Facilities Manager - South','2026-08-20',null,'Vendor has committed a standby technician for weekend shifts starting next cycle'),
    ('Bhiwadi Warehouse','Vendor crew attrition left site short-staffed for nine of thirty scheduled visits','Enforce minimum-crew SLA clause and require a chemical-usage log for every visit','overdue','Facilities Manager - West','2026-07-31',null,'SLA breached by two weeks; replacement crew onboarding delayed by vendor'),
    ('Taloja Yard','Monsoon flooding blocked vendor access for two scheduled deep-clean visits','Reschedule deferred visits to first dry week and add a monsoon contingency clause to the AMC','in_progress','Facilities Manager - West','2026-08-15',null,'One of two deferred visits completed; second scheduled once access road clears'),
    ('Kolkata Branch Office','Pest treatment protocol ineffective against recurring cockroach infestation','Switch vendor treatment chemical and add gel-bait application in kitchen zones','open','Facilities Manager - East','2026-08-28',null,'Vendor proposing revised treatment plan after third consecutive complaint this quarter'),
    ('Okhla Depot','Vendor repeatedly unavailable for scheduled fumigation causing rising pest sightings','Issue vendor default notice and onboard an alternate fumigation contractor','overdue','Facilities Manager - North','2026-07-20',null,'Default notice issued; alternate vendor onboarding in progress, three weeks overdue'),
    ('Nashik Depot','Dispenser refill stock not adequately pre-positioned for mid-week demand','Increase on-site consumable buffer stock and add a mid-week stock check to the visit checklist','closed','Facilities Manager - West','2026-07-15','2026-07-12','Buffer stock increased and mid-week check added to SOP; audit score recovered next cycle'),
    ('Guwahati Hub','AMC renewal approaching without finance sign-off on revised rate card','Complete AMC renewal negotiation and secure finance approval before expiry','in_progress','Facilities Manager - East','2026-08-24',null,'Rate card under review; renewal expected to close within contract-expiry window')
  ) as q(sn, rc, ca, cst, ownr, tcd, acd, nt)
  join public.hk_pest_amc_r3742 e
    on e.organization_id = v_org_id and e.site_name = q.sn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3742_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hk_pest_amc_r3742)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hk_pest_amc_r3742 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3742_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3742_compliance_status_rollup() to authenticated;

-- 2) Site scorecard
create or replace function public.founder_r3742_site_scorecard()
returns table(
  site_name text,
  records bigint,
  compliant bigint,
  minor_gap bigint,
  visit_shortfall bigint,
  quality_issue bigint,
  contract_expiring bigint,
  avg_visit_compliance_pct numeric,
  avg_audit_score numeric,
  pest_incidents_total bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'minor_gap')::bigint,
    count(*) filter (where l.compliance_status = 'visit_shortfall')::bigint,
    count(*) filter (where l.compliance_status = 'quality_issue')::bigint,
    count(*) filter (where l.compliance_status = 'contract_expiring')::bigint,
    round(avg(l.visit_compliance_pct), 1),
    round(avg(l.audit_score), 1),
    coalesce(sum(l.pest_incidents_reported),0)::bigint
  from public.hk_pest_amc_r3742 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3742_site_scorecard() from public, anon;
grant execute on function public.founder_r3742_site_scorecard() to authenticated;

-- 3) Service-class × compliance-status matrix
create or replace function public.founder_r3742_service_class_status_matrix()
returns table(service_class text, compliance_status text, records bigint, avg_visit_compliance_pct numeric, avg_audit_score numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_class, l.compliance_status, count(*)::bigint,
    round(avg(l.visit_compliance_pct), 1),
    round(avg(l.audit_score), 1)
  from public.hk_pest_amc_r3742 l
  group by l.service_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3742_service_class_status_matrix() from public, anon;
grant execute on function public.founder_r3742_service_class_status_matrix() to authenticated;

-- 4) Monthly visit-compliance trend
create or replace function public.founder_r3742_monthly_visit_compliance_trend()
returns table(
  period_month date,
  records bigint,
  avg_visit_compliance_pct numeric,
  avg_audit_score numeric,
  pest_incidents_total bigint,
  worsening_records bigint
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
    round(avg(l.visit_compliance_pct), 1),
    round(avg(l.audit_score), 1),
    coalesce(sum(l.pest_incidents_reported),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.hk_pest_amc_r3742 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3742_monthly_visit_compliance_trend() from public, anon;
grant execute on function public.founder_r3742_monthly_visit_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3742_capa_status_board()
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
  from public.hk_pest_amc_capa_actions_r3742 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3742_capa_status_board() from public, anon;
grant execute on function public.founder_r3742_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3742_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hk_pest_amc_capa_actions_r3742)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hk_pest_amc_capa_actions_r3742 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3742_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3742_root_cause_pareto() to authenticated;

-- 7) Pest-incident digest (sites with pest incidents or chemical-compliance gaps)
create or replace function public.founder_r3742_pest_incident_digest()
returns table(
  site_name text,
  records bigint,
  pest_incidents_total bigint,
  chemical_noncompliant_records bigint,
  avg_audit_score numeric,
  worsening_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.pest_incidents_reported),0)::bigint,
    count(*) filter (where l.chemical_compliance_verified = false)::bigint,
    round(avg(l.audit_score), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.hk_pest_amc_r3742 l
  where coalesce(l.pest_incidents_reported,0) > 0 or l.chemical_compliance_verified = false
  group by l.site_name
  order by coalesce(sum(l.pest_incidents_reported),0) desc;
end;
$$;

revoke all on function public.founder_r3742_pest_incident_digest() from public, anon;
grant execute on function public.founder_r3742_pest_incident_digest() to authenticated;

-- 8) High-risk compliance queue (visit-shortfall / quality-issue, worst first)
create or replace function public.founder_r3742_high_risk_queue()
returns table(
  site_name text,
  service_class text,
  period_month date,
  compliance_status text,
  visit_compliance_pct numeric,
  audit_score numeric,
  pest_incidents_reported int,
  chemical_compliance_verified boolean,
  vendor_name text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.service_class, l.period_month, l.compliance_status,
    l.visit_compliance_pct, l.audit_score, l.pest_incidents_reported,
    l.chemical_compliance_verified, l.vendor_name, l.notes
  from public.hk_pest_amc_r3742 l
  where l.compliance_status in ('visit_shortfall','quality_issue')
  order by l.visit_compliance_pct asc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3742_high_risk_queue() from public, anon;
grant execute on function public.founder_r3742_high_risk_queue() to authenticated;
