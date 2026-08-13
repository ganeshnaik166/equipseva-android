-- Round 3734: Founder OEM-Authorized Dealer / Service-Center Certification Board
-- OEM-authorized dealer/service-center certifications held by EquipSeva per equipment brand —
-- validity, technician headcount certified, audit findings, renewal status.
-- Distinct from any engineer-tool-calibration or engineer-refurbishment-recertification board,
-- which is about TOOLS/used-equipment, not the COMPANY's own OEM authorization status.

-- =============================================================================
-- TABLE 1: oem_authoriz_r3734 — OEM authorization / certification facts
-- =============================================================================
create table if not exists public.oem_authoriz_r3734 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  oem_brand text not null,
  service_center_location text not null,
  period_month date not null,
  certification_ref text,
  issue_date date,
  expiry_date date,
  days_to_expiry int,
  technicians_certified int,
  technicians_required int,
  last_audit_score numeric,
  audit_findings_open int,
  renewal_fee_rupees numeric(12,2),
  cert_class text not null check (cert_class in (
    'service_authorization','sales_dealership','training_partner','spare_parts_distributor','warranty_repair_center'
  )),
  cert_status text not null check (cert_status in (
    'active_compliant','renewal_due_soon','renewal_overdue','suspended','revoked'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_authoriz_r3734 enable row level security;

create index if not exists idx_oem_authoriz_r3734_org on public.oem_authoriz_r3734(organization_id);
create index if not exists idx_oem_authoriz_r3734_month on public.oem_authoriz_r3734(period_month);
create index if not exists idx_oem_authoriz_r3734_status on public.oem_authoriz_r3734(cert_status);

-- =============================================================================
-- TABLE 2: oem_authoriz_capa_actions_r3734 — CAPA for certification gaps
-- =============================================================================
create table if not exists public.oem_authoriz_capa_actions_r3734 (
  id uuid primary key default gen_random_uuid(),
  cert_id uuid references public.oem_authoriz_r3734(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_authoriz_capa_actions_r3734 enable row level security;

create index if not exists idx_oem_authoriz_capa_actions_r3734_cert on public.oem_authoriz_capa_actions_r3734(cert_id);
create index if not exists idx_oem_authoriz_capa_actions_r3734_status on public.oem_authoriz_capa_actions_r3734(capa_status);

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

  -- 16 certification rows
  insert into public.oem_authoriz_r3734 (
    organization_id, oem_brand, service_center_location, period_month, certification_ref,
    issue_date, expiry_date, days_to_expiry, technicians_certified, technicians_required,
    last_audit_score, audit_findings_open, renewal_fee_rupees, cert_class, cert_status,
    trend_dir, notes
  )
  select v_org_id, q.brand, q.loc, q.pm::date, q.cref,
    q.isd::date, q.exd::date, q.dte::int, q.tc::int, q.tr::int,
    q.las::numeric, q.afo::int, q.rfr::numeric, q.cc, q.cs, q.td, q.nt
  from (values
    ('Caterpillar','Pune','2026-07-01','CAT-SA-2024-1187','2024-08-01','2027-07-31',730,14,12,92.5,1,185000.00,'service_authorization','active_compliant','improving','Annual OEM audit cleared with one minor finding on tool-calibration logs; technician bench strength above required headcount.'),
    ('JCB','Chennai','2026-07-01','JCB-SD-2023-0542','2023-09-15','2026-09-14',40,9,10,81.0,3,95000.00,'sales_dealership','active_compliant','stable','Renewal packet already filed with OEM regional office ahead of the September deadline.'),
    ('Komatsu','Bengaluru','2026-07-01','KOM-TP-2022-0311','2022-10-01','2026-09-30',56,6,8,78.5,4,65000.00,'training_partner','renewal_due_soon','stable','Two certified-trainer slots vacant; refresher workshops being scheduled before renewal audit.'),
    ('Volvo CE','Ahmedabad','2026-06-01','VCE-SP-2021-0098','2021-07-01','2026-06-30',-18,5,6,68.0,6,110000.00,'spare_parts_distributor','renewal_overdue','worsening','Renewal fee release stuck in finance approval; OEM issued formal non-compliance warning.'),
    ('Tata Hitachi','Nagpur','2026-06-01','TH-WR-2023-0765','2023-11-01','2026-10-31',120,11,10,88.0,2,78000.00,'warranty_repair_center','active_compliant','improving','Warranty repair turnaround times consistently within OEM SLA this quarter.'),
    ('L&T Construction Equipment','Kolkata','2026-06-01','LNT-SA-2020-0233','2020-05-01','2027-04-30',400,7,12,42.0,8,132000.00,'service_authorization','suspended','worsening','Authorization suspended after OEM audit found tool-calibration records lapsed for three quarters.'),
    ('Ashok Leyland','Hyderabad','2026-07-01','AL-SD-2024-0456','2024-03-01','2026-09-01',33,8,8,84.0,2,92000.00,'sales_dealership','renewal_due_soon','stable','OEM dealership performance review scheduled ahead of the September renewal window.'),
    ('Mahindra Construction Equipment','Delhi NCR','2026-05-01','MCE-TP-2022-0187','2022-06-01','2027-05-31',395,10,9,90.0,0,58000.00,'training_partner','active_compliant','improving','Full trainer headcount maintained; zero open audit findings for the second cycle running.'),
    ('Escorts Kubota','Indore','2026-05-01','EK-SP-2023-0299','2023-04-01','2027-03-31',330,6,6,86.5,1,48000.00,'spare_parts_distributor','active_compliant','stable','Genuine-parts stocking ratio comfortably above OEM distributor threshold.'),
    ('Bull Machines','Coimbatore','2026-05-01','BM-WR-2021-0154','2021-02-01','2026-04-30',-95,4,6,60.0,5,42000.00,'warranty_repair_center','renewal_overdue','worsening','Renewal application rejected once for incomplete technician certificates; resubmission pending.'),
    ('Caterpillar','Nashik','2026-06-01','CAT-SD-2019-0071','2019-01-01','2025-12-31',-180,2,8,35.0,9,15000.00,'sales_dealership','revoked','worsening','Dealership authorization revoked after repeated warranty-claim documentation fraud findings; appeal filed.'),
    ('JCB','Jaipur','2026-07-01','JCB-WR-2024-0812','2024-01-15','2027-01-14',160,9,8,89.0,1,71000.00,'warranty_repair_center','active_compliant','improving','Warranty repair-center audit score improved for the third consecutive cycle.'),
    ('Komatsu','Vadodara','2026-05-01','KOM-SA-2023-0421','2023-05-01','2026-09-15',45,7,10,79.0,3,84000.00,'service_authorization','renewal_due_soon','stable','Genuine-parts usage ratio dipped below OEM threshold; corrective retraining underway.'),
    ('Volvo CE','Lucknow','2026-07-01','VCE-TP-2022-0356','2022-08-01','2027-07-31',700,3,6,48.0,7,39000.00,'training_partner','suspended','worsening','Training-partner status suspended after certified-trainer headcount fell below OEM minimum.'),
    ('Tata Hitachi','Guwahati','2026-06-01','TH-SP-2023-0512','2023-06-01','2026-08-31',25,5,6,82.0,2,51000.00,'spare_parts_distributor','renewal_due_soon','stable','Renewal documentation in final review; no major findings expected.'),
    ('L&T Construction Equipment','Surat','2026-05-01','LNT-SA-2024-0623','2024-02-01','2027-01-31',260,13,11,94.0,0,165000.00,'service_authorization','active_compliant','improving','Highest audit score in the network this cycle; technician bench exceeds OEM requirement.')
  ) as q(brand, loc, pm, cref, isd, exd, dte, tc, tr, las, afo, rfr, cc, cs, td, nt);

  -- 8 CAPA rows — attach to certifications via certification_ref
  insert into public.oem_authoriz_capa_actions_r3734 (
    cert_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('VCE-SP-2021-0098','Renewal fee payment stuck in finance approval workflow','Escalate renewal fee release to finance director and file renewal within 5 days','in_progress','Compliance Manager','2026-08-20',null,'OEM has issued a formal non-compliance warning; distributor status at risk of downgrade.'),
    ('LNT-SA-2020-0233','Tool-calibration records lapsed for three consecutive quarters','Re-certify calibration lab and submit evidence pack to OEM auditor','open','Service Quality Head','2026-08-30',null,'Suspension blocks warranty-claim submissions at this center until lifted.'),
    ('BM-WR-2021-0154','Renewal application rejected for incomplete technician certification proofs','Resubmit technician certificates and refile renewal application','overdue','Branch Service Manager','2026-07-25',null,'Second rejection risk if documentation gaps repeat; escalated to regional head.'),
    ('CAT-SD-2019-0071','Repeated warranty-claim documentation fraud findings over two audit cycles','File formal appeal with OEM and replace dealership compliance team','in_progress','Regional Director','2026-09-15',null,'Appeal hearing scheduled; interim sales activity suspended pending outcome.'),
    ('VCE-TP-2022-0356','Certified-trainer headcount fell below OEM minimum after two resignations','Hire and OEM-certify two replacement trainers within the quarter','open','HR & Training Lead','2026-09-05',null,'Training-partner revenue line paused until trainer headcount is restored.'),
    ('KOM-TP-2022-0311','Trainer skill-refresh workshops missed for two cycles','Schedule catch-up refresher workshops before the renewal audit','in_progress','Training Coordinator','2026-08-28',null,'Renewal audit scheduled early September; workshop backlog must clear first.'),
    ('KOM-SA-2023-0421','Spare-parts genuine-usage ratio dipped below OEM threshold','Audit non-genuine parts usage and retrain service advisors on genuine-parts policy','closed','Service Quality Head','2026-07-10','2026-07-08','Genuine-parts ratio restored above threshold ahead of the renewal review.'),
    ('AL-SD-2024-0456','Sales-target shortfall triggered OEM dealership performance review','Submit revised sales-growth plan and complete OEM dealership review call','open','Dealership Principal','2026-09-01',null,'OEM review call scheduled; renewal contingent on the approved growth plan.')
  ) as q(cref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.oem_authoriz_r3734 e
    on e.organization_id = v_org_id and e.certification_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Certification-status distribution
create or replace function public.founder_r3734_cert_status_rollup()
returns table(cert_status text, certs bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_authoriz_r3734)
  select l.cert_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oem_authoriz_r3734 l
  group by l.cert_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_cert_status_rollup() from public, anon;
grant execute on function public.founder_r3734_cert_status_rollup() to authenticated;

-- 2) OEM-brand scorecard
create or replace function public.founder_r3734_oem_brand_scorecard()
returns table(
  oem_brand text,
  certs bigint,
  active_compliant bigint,
  renewal_overdue bigint,
  avg_last_audit_score numeric,
  avg_technicians_certified numeric,
  audit_findings_open_total bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_brand,
    count(*)::bigint,
    count(*) filter (where l.cert_status = 'active_compliant')::bigint,
    count(*) filter (where l.cert_status = 'renewal_overdue')::bigint,
    round(avg(l.last_audit_score), 1),
    round(avg(l.technicians_certified), 1),
    coalesce(sum(l.audit_findings_open), 0)::bigint
  from public.oem_authoriz_r3734 l
  group by l.oem_brand
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_oem_brand_scorecard() from public, anon;
grant execute on function public.founder_r3734_oem_brand_scorecard() to authenticated;

-- 3) Cert-class × cert-status matrix
create or replace function public.founder_r3734_cert_class_status_matrix()
returns table(cert_class text, cert_status text, certs bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cert_class, l.cert_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1)
  from public.oem_authoriz_r3734 l
  group by l.cert_class, l.cert_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_cert_class_status_matrix() from public, anon;
grant execute on function public.founder_r3734_cert_class_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3734_monthly_expiry_trend()
returns table(
  period_month date,
  certs bigint,
  avg_days_to_expiry numeric,
  renewals_due_soon bigint,
  renewals_overdue bigint
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
    round(avg(l.days_to_expiry), 1),
    count(*) filter (where l.cert_status = 'renewal_due_soon')::bigint,
    count(*) filter (where l.cert_status = 'renewal_overdue')::bigint
  from public.oem_authoriz_r3734 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3734_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3734_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3734_capa_status_board()
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
  from public.oem_authoriz_capa_actions_r3734 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_capa_status_board() from public, anon;
grant execute on function public.founder_r3734_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3734_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_authoriz_capa_actions_r3734)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oem_authoriz_capa_actions_r3734 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3734_root_cause_pareto() to authenticated;

-- 7) Audit-finding digest (certs with open audit findings)
create or replace function public.founder_r3734_audit_finding_digest()
returns table(
  cert_class text,
  certs bigint,
  audit_findings_open_total bigint,
  avg_last_audit_score numeric,
  low_score_certs bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cert_class,
    count(*)::bigint,
    coalesce(sum(l.audit_findings_open), 0)::bigint,
    round(avg(l.last_audit_score), 1),
    count(*) filter (where l.last_audit_score < 70)::bigint
  from public.oem_authoriz_r3734 l
  where l.audit_findings_open > 0
  group by l.cert_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3734_audit_finding_digest() from public, anon;
grant execute on function public.founder_r3734_audit_finding_digest() to authenticated;

-- 8) High-risk certification queue (overdue / suspended / revoked, worst first)
create or replace function public.founder_r3734_high_risk_queue()
returns table(
  oem_brand text,
  service_center_location text,
  certification_ref text,
  cert_class text,
  cert_status text,
  period_month date,
  expiry_date date,
  days_to_expiry int,
  technicians_certified int,
  technicians_required int,
  audit_findings_open int,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_brand, l.service_center_location, l.certification_ref, l.cert_class,
    l.cert_status, l.period_month, l.expiry_date, l.days_to_expiry,
    l.technicians_certified, l.technicians_required, l.audit_findings_open, l.notes
  from public.oem_authoriz_r3734 l
  where l.cert_status in ('renewal_overdue','suspended','revoked')
  order by l.days_to_expiry asc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3734_high_risk_queue() from public, anon;
grant execute on function public.founder_r3734_high_risk_queue() to authenticated;
