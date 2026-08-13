-- Round 3723: Founder Vendor Blacklist / Debarment Compliance Register
-- Vendor/supplier blacklist & debarment register — grounds for debarment, review/appeal status,
-- re-engagement eligibility, prior spend exposure. Distinct from vendor-contract-RISK-REGISTER and
-- vendor-contract-VAULT pages, which track live contract risk, not debarment actions.

-- =============================================================================
-- TABLE 1: vendor_debar_r3723 — vendor debarment / blacklist register facts
-- =============================================================================
create table if not exists public.vendor_debar_r3723 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  supply_category text not null,
  period_month date not null,
  debarment_ref text not null,
  debarment_date date,
  review_due_date date,
  prior_annual_spend_rupees numeric(12,2),
  appeal_filed boolean not null,
  appeal_outcome text,
  reinstatement_eligible boolean not null,
  alternate_vendor_identified boolean not null,
  debarment_reason_class text not null check (debarment_reason_class in (
    'quality_failure','fraud_integrity','statutory_noncompliance','safety_violation','repeated_sla_breach'
  )),
  debarment_status text not null check (debarment_status in (
    'active_debarment','under_review','appeal_pending','reinstated','permanent_ban'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_debar_r3723 enable row level security;

create index if not exists idx_vendor_debar_r3723_org on public.vendor_debar_r3723(organization_id);
create index if not exists idx_vendor_debar_r3723_month on public.vendor_debar_r3723(period_month);
create index if not exists idx_vendor_debar_r3723_status on public.vendor_debar_r3723(debarment_status);

-- =============================================================================
-- TABLE 2: vendor_debar_capa_actions_r3723 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.vendor_debar_capa_actions_r3723 (
  id uuid primary key default gen_random_uuid(),
  debar_id uuid references public.vendor_debar_r3723(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_debar_capa_actions_r3723 enable row level security;

create index if not exists idx_vendor_debar_capa_r3723_debar on public.vendor_debar_capa_actions_r3723(debar_id);
create index if not exists idx_vendor_debar_capa_r3723_status on public.vendor_debar_capa_actions_r3723(capa_status);

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

  -- 16 vendor debarment rows
  insert into public.vendor_debar_r3723 (
    organization_id, vendor_name, supply_category, period_month, debarment_ref,
    debarment_date, review_due_date, prior_annual_spend_rupees, appeal_filed, appeal_outcome,
    reinstatement_eligible, alternate_vendor_identified, debarment_reason_class,
    debarment_status, trend_dir, notes
  )
  select v_org_id, q.vn, q.sc, q.pm::date, q.dref,
    q.ddate::date, q.rdue::date, q.spend::numeric, q.afil, q.aout,
    q.reelig, q.altv, q.rcls,
    q.dst, q.trd, q.nt
  from (values
    ('Shakti Hydraulics Pvt Ltd','Hydraulic Cylinders','2026-07-01','DEB-2026-0031',
     '2026-06-15','2026-12-15','8400000.00',true,'rejected',false,true,'quality_failure','active_debarment','worsening','Repeat seal-failure batches traced to sub-standard chrome plating — appeal rejected'),
    ('Vardhman Steel Traders','Structural Steel','2026-07-01','DEB-2026-0032',
     '2026-05-20','2026-11-20','15200000.00',true,'pending',false,false,'fraud_integrity','appeal_pending','stable','Mill-test-certificate forgery discovered on 3 consignments — appeal under legal review'),
    ('Om Sai Tyres & Rubber','Tyres & Tubes','2026-06-01','DEB-2026-0028',
     '2026-04-10','2026-10-10','6300000.00',false,null,false,true,'safety_violation','active_debarment','stable','Retreaded tyres sold as new — DGCA-equivalent safety audit flagged'),
    ('Krishna Electricals Co','Electrical Spares','2026-07-01','DEB-2026-0033',
     null,'2026-09-30','2100000.00',false,null,true,false,'repeated_sla_breach','under_review','improving','Six consecutive late-delivery SLA breaches — placed under review pending Q3 performance'),
    ('Bharat Fasteners Ltd','Fasteners & Hardware','2026-05-01','DEB-2026-0021',
     '2025-11-05','2026-05-05','1850000.00',true,'upheld',true,true,'statutory_noncompliance','reinstated','improving','GST-registration lapse resolved and verified — reinstated with 6-month monitoring'),
    ('Ganges Lubricants Pvt Ltd','Lubricants & Fluids','2026-06-01','DEB-2026-0026',
     '2026-01-12','2026-07-12','3400000.00',true,'upheld',true,false,'quality_failure','reinstated','stable','Off-spec viscosity batch resolved via new QC vendor audit — appeal upheld'),
    ('National Crane Components','Crane Parts','2026-07-01','DEB-2026-0034',
     '2026-07-01','2027-01-01','22500000.00',false,null,false,false,'fraud_integrity','permanent_ban','worsening','Kickback scheme involving procurement staff — permanent ban, matter with vigilance cell'),
    ('Suraj Batteries Ltd','Batteries','2026-05-01','DEB-2026-0022',
     '2026-02-18','2026-08-18','2750000.00',true,'rejected',false,true,'safety_violation','active_debarment','worsening','Thermal-runaway incident on site — appeal rejected pending independent forensic report'),
    ('Amrit Filters & Hoses','Filters & Hoses','2026-06-01','DEB-2026-0027',
     null,'2026-11-01','1450000.00',false,null,true,false,'repeated_sla_breach','under_review','stable','Under review after three missed dispatch windows this quarter'),
    ('Deccan Paints Industries','Paints & Coatings','2026-07-01','DEB-2026-0035',
     '2026-06-28','2026-12-28','980000.00',true,'pending',false,true,'quality_failure','appeal_pending','worsening','Coating-adhesion failures on 40% of delivered drums — appeal hearing scheduled'),
    ('Metro Logistics Carriers','Third-Party Logistics','2026-04-01','DEB-2026-0018',
     '2025-10-01','2026-04-01','5600000.00',true,'upheld',true,true,'statutory_noncompliance','reinstated','improving','Missing transporter permits regularized — reinstated after compliance re-audit'),
    ('Jyoti Precision Castings','Machined Castings','2026-07-01','DEB-2026-0036',
     '2026-07-05',null,4200000.00,false,null,false,false,'fraud_integrity','permanent_ban','worsening','Falsified dimensional inspection reports on safety-critical castings — permanent ban issued'),
    ('Reliable Hose Solutions','Hydraulic Hoses','2026-06-01','DEB-2026-0029',
     '2026-05-02','2026-11-02','1620000.00',true,'pending',false,false,'safety_violation','appeal_pending','stable','Burst-pressure test failures on two lots — appeal under technical committee review'),
    ('Sunrise Sheet Metal Works','Sheet Metal Fabrication','2026-05-01','DEB-2026-0023',
     '2026-03-11','2026-09-11','2980000.00',false,null,true,true,'repeated_sla_breach','under_review','improving','On-time delivery recovered to 92% since March — review favors early reinstatement'),
    ('Aegis Compliance Testing Labs','Third-Party Inspection','2026-07-01','DEB-2026-0037',
     '2026-06-10','2026-12-10','1120000.00',true,'rejected',false,true,'statutory_noncompliance','active_debarment','worsening','Inspection lab found operating without valid NABL accreditation — appeal rejected'),
    ('Vintage Wire & Cable Co','Cables & Wiring','2026-04-01','DEB-2026-0019',
     '2025-09-15','2026-03-15','1980000.00',true,'upheld',true,false,'quality_failure','reinstated','stable','Insulation-thickness defects corrected via new extrusion line — reinstated with sampling plan')
  ) as q(vn, sc, pm, dref, ddate, rdue, spend, afil, aout, reelig, altv, rcls, dst, trd, nt);

  -- CAPA seed — attach to specific debarments via debarment_ref
  insert into public.vendor_debar_capa_actions_r3723 (
    debar_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEB-2026-0031','Sub-standard chrome plating vendor used without incoming QC hold','Add mandatory third-party plating audit before batch release','in_progress','Quality Head','2026-09-15',null,'Alternate plating vendor being qualified in parallel'),
    ('DEB-2026-0032','Mill-test-certificate forgery not caught at receipt inspection','Introduce digital MTC verification against mill registry','open','Procurement Compliance Lead','2026-09-30',null,'Legal notice issued; forensic document review in progress'),
    ('DEB-2026-0028','Retread tyres mis-declared as new stock','Mandate DOT-code photo evidence at every tyre GRN','closed','Fleet Procurement Manager','2026-07-20','2026-07-18','New GRN checklist live across all yards'),
    ('DEB-2026-0034','Vendor onboarding skipped anti-corruption declaration step','Enforce mandatory integrity pact for all new crane-parts vendors','overdue','Chief Procurement Officer','2026-08-01',null,'Vigilance cell investigation delaying policy sign-off'),
    ('DEB-2026-0022','Battery thermal-management spec not verified pre-award','Add mandatory UN38.3 test report to vendor qualification','in_progress','Safety Officer','2026-09-05',null,'Independent forensic lab report awaited before appeal decision'),
    ('DEB-2026-0035','Coating batch QC sampling rate too low for drum lots','Raise sampling AQL and add adhesion pull-test at receipt','open','Quality Head','2026-09-20',null,'Interim alternate coating vendor shortlisted'),
    ('DEB-2026-0036','Dimensional inspection sign-off not cross-verified by second inspector','Introduce dual-sign-off for safety-critical casting inspection reports','closed','Quality Head','2026-08-05','2026-08-04','Permanent ban stands; process fix applied to remaining approved vendors'),
    ('DEB-2026-0029','Burst-pressure test data not independently witnessed','Require witnessed burst-test video evidence per lot going forward','in_progress','Technical Committee Chair','2026-09-10',null,'Two lots retested under witnessed protocol pending appeal outcome')
  ) as q(dref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.vendor_debar_r3723 e
    on e.organization_id = v_org_id and e.debarment_ref = q.dref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Debarment-status distribution
create or replace function public.founder_r3723_debarment_status_rollup()
returns table(debarment_status text, vendors bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_debar_r3723)
  select l.debarment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_debar_r3723 l
  group by l.debarment_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3723_debarment_status_rollup() from public, anon;
grant execute on function public.founder_r3723_debarment_status_rollup() to authenticated;

-- 2) Supply-category scorecard
create or replace function public.founder_r3723_supply_category_scorecard()
returns table(
  supply_category text,
  vendors bigint,
  active_debarments bigint,
  under_review bigint,
  appeal_pending bigint,
  reinstated bigint,
  permanent_bans bigint,
  alternate_identified bigint,
  total_prior_spend_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supply_category,
    count(*)::bigint,
    count(*) filter (where l.debarment_status = 'active_debarment')::bigint,
    count(*) filter (where l.debarment_status = 'under_review')::bigint,
    count(*) filter (where l.debarment_status = 'appeal_pending')::bigint,
    count(*) filter (where l.debarment_status = 'reinstated')::bigint,
    count(*) filter (where l.debarment_status = 'permanent_ban')::bigint,
    count(*) filter (where l.alternate_vendor_identified = true)::bigint,
    coalesce(sum(l.prior_annual_spend_rupees),0)::numeric
  from public.vendor_debar_r3723 l
  group by l.supply_category
  order by coalesce(sum(l.prior_annual_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3723_supply_category_scorecard() from public, anon;
grant execute on function public.founder_r3723_supply_category_scorecard() to authenticated;

-- 3) Debarment-reason-class × status matrix
create or replace function public.founder_r3723_debarment_reason_class_status_matrix()
returns table(debarment_reason_class text, debarment_status text, vendors bigint, total_prior_spend_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.debarment_reason_class, l.debarment_status, count(*)::bigint,
    coalesce(sum(l.prior_annual_spend_rupees),0)::numeric
  from public.vendor_debar_r3723 l
  group by l.debarment_reason_class, l.debarment_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3723_debarment_reason_class_status_matrix() from public, anon;
grant execute on function public.founder_r3723_debarment_reason_class_status_matrix() to authenticated;

-- 4) Monthly debarment trend
create or replace function public.founder_r3723_monthly_debarment_trend()
returns table(period_month date, vendors bigint, new_debarments bigint, reinstated bigint, permanent_bans bigint, total_prior_spend_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.debarment_status = 'active_debarment')::bigint,
    count(*) filter (where l.debarment_status = 'reinstated')::bigint,
    count(*) filter (where l.debarment_status = 'permanent_ban')::bigint,
    coalesce(sum(l.prior_annual_spend_rupees),0)::numeric
  from public.vendor_debar_r3723 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3723_monthly_debarment_trend() from public, anon;
grant execute on function public.founder_r3723_monthly_debarment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3723_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.vendor_debar_capa_actions_r3723 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3723_capa_status_board() from public, anon;
grant execute on function public.founder_r3723_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3723_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_debar_capa_actions_r3723)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_debar_capa_actions_r3723 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3723_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3723_root_cause_pareto() to authenticated;

-- 7) Exposure digest — prior-spend exposure by reason class
create or replace function public.founder_r3723_exposure_digest()
returns table(
  debarment_reason_class text,
  vendors bigint,
  total_prior_spend_rupees numeric,
  no_alternate_vendor bigint,
  appeals_filed bigint,
  reinstatement_eligible bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.debarment_reason_class,
    count(*)::bigint,
    coalesce(sum(l.prior_annual_spend_rupees),0)::numeric,
    count(*) filter (where l.alternate_vendor_identified = false)::bigint,
    count(*) filter (where l.appeal_filed = true)::bigint,
    count(*) filter (where l.reinstatement_eligible = true)::bigint
  from public.vendor_debar_r3723 l
  group by l.debarment_reason_class
  order by coalesce(sum(l.prior_annual_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3723_exposure_digest() from public, anon;
grant execute on function public.founder_r3723_exposure_digest() to authenticated;

-- 8) High-risk debarment queue (active debarments / permanent bans with no alternate vendor)
create or replace function public.founder_r3723_high_risk_queue()
returns table(
  vendor_name text,
  supply_category text,
  debarment_ref text,
  debarment_status text,
  debarment_reason_class text,
  review_due_date date,
  prior_annual_spend_rupees numeric,
  alternate_vendor_identified boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.supply_category, l.debarment_ref, l.debarment_status,
    l.debarment_reason_class, l.review_due_date, l.prior_annual_spend_rupees,
    l.alternate_vendor_identified, l.notes
  from public.vendor_debar_r3723 l
  where l.debarment_status in ('active_debarment','permanent_ban')
  order by l.alternate_vendor_identified asc, l.prior_annual_spend_rupees desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3723_high_risk_queue() from public, anon;
grant execute on function public.founder_r3723_high_risk_queue() to authenticated;
