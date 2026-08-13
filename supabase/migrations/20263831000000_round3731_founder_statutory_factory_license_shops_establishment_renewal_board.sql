-- Round 3731: Founder Statutory Factory License / Shops & Establishments Renewal Board
-- Factory license (Factories Act) and Shops & Establishments Act registration renewals per
-- site -- validity, renewal lead-time, inspection findings x CAPA. Distinct from any
-- medical-device-registration-license-renewal page, which is PRODUCT regulatory, not
-- premises/labour statutory licensing.

-- =============================================================================
-- TABLE 1: factory_license_r3731 -- per-site statutory factory/S&E license facts
-- =============================================================================
create table if not exists public.factory_license_r3731 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  license_type text not null,
  period_month date not null,
  license_number text,
  issue_date date,
  expiry_date date,
  days_to_expiry int,
  renewal_filed boolean not null,
  renewal_filed_date date,
  inspection_due boolean not null,
  inspection_findings_open int,
  penalty_rupees numeric(12,2),
  license_class text not null check (license_class in (
    'factory_license','shops_establishment','labour_license','contract_labour_license','pollution_consent'
  )),
  renewal_status text not null check (renewal_status in (
    'active_valid','renewal_filed','renewal_overdue','expired_lapsed','inspection_pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.factory_license_r3731 enable row level security;

create index if not exists idx_factory_license_r3731_org on public.factory_license_r3731(organization_id);
create index if not exists idx_factory_license_r3731_month on public.factory_license_r3731(period_month);
create index if not exists idx_factory_license_r3731_status on public.factory_license_r3731(renewal_status);

-- =============================================================================
-- TABLE 2: factory_license_capa_actions_r3731 -- CAPA & renewal remediation actions
-- =============================================================================
create table if not exists public.factory_license_capa_actions_r3731 (
  id uuid primary key default gen_random_uuid(),
  factory_license_id uuid references public.factory_license_r3731(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.factory_license_capa_actions_r3731 enable row level security;

create index if not exists idx_factory_license_capa_r3731_fk on public.factory_license_capa_actions_r3731(factory_license_id);
create index if not exists idx_factory_license_capa_r3731_status on public.factory_license_capa_actions_r3731(capa_status);

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

  -- 16 factory-license / shops & establishments rows
  insert into public.factory_license_r3731 (
    organization_id, site_name, license_type, period_month, license_number,
    issue_date, expiry_date, days_to_expiry, renewal_filed, renewal_filed_date,
    inspection_due, inspection_findings_open, penalty_rupees, license_class,
    renewal_status, trend_dir, notes
  )
  select v_org_id, q.site, q.ltype, q.pm::date, q.lnum,
    q.idate::date, q.edate::date, q.dte::int, q.rfiled, q.rfdate::date,
    q.idue, q.ifo::int, q.pen::numeric, q.lclass,
    q.rstatus, q.trd, q.nt
  from (values
    ('Chennai Plant 1','Factory License - Section 6','2026-07-01','TN/FAC/2019/4521',
     '2024-04-01','2027-03-31',235,true,'2026-06-10',false,0,0.00,'factory_license','active_valid','stable',
     'Renewed early, all inspections clear'),
    ('Chennai Plant 1','Shops & Establishments Registration','2026-07-01','TN/SE/2021/7743',
     '2025-01-01','2026-12-31',145,false,null,false,0,0.00,'shops_establishment','active_valid','stable',
     'Valid through year-end, no action needed'),
    ('Pune Assembly Unit','Contract Labour License (Principal Employer)','2026-07-01','MH/CLRA/2020/1102',
     '2024-08-01','2026-07-31',18,true,'2026-07-05',false,0,0.00,'contract_labour_license','renewal_filed','improving',
     'Renewal filed well ahead of expiry, awaiting Labour Dept approval'),
    ('Pune Assembly Unit','Pollution Control Consent to Operate','2026-06-01','MH/PCB/CTO/2023/556',
     '2023-06-01','2026-05-31',-31,false,null,true,2,25000.00,'pollution_consent','expired_lapsed','worsening',
     'CTO lapsed, SPCB flagged two open findings during surprise inspection'),
    ('Nashik Warehouse','Shops & Establishments Registration','2026-06-01','MH/SE/2019/3345',
     '2024-04-01','2026-03-31',-92,false,null,false,0,15000.00,'shops_establishment','expired_lapsed','worsening',
     'Renewal reminder missed, penalty accrued for delayed filing'),
    ('Faridabad Unit 2','Factory License - Section 6','2026-07-01','HR/FAC/2018/9012',
     '2023-05-01','2026-07-20',12,false,null,true,1,0.00,'factory_license','renewal_overdue','worsening',
     'Statutory 60-day advance filing window missed; expiry in 12 days'),
    ('Vizag Service Center','Labour License - CLRA','2026-07-01','AP/CLRA/2021/2290',
     '2024-09-01','2026-08-31',43,true,'2026-07-10',false,0,0.00,'labour_license','renewal_filed','stable',
     'Renewal filed on schedule, no findings pending'),
    ('Hosur Manufacturing Unit','Factory License - Section 6','2026-06-01','TN/FAC/2017/6634',
     '2022-03-01','2027-02-28',272,false,null,true,3,0.00,'factory_license','inspection_pending','worsening',
     'Chief Inspector flagged fire-safety NOC during last visit, three findings open'),
    ('Baddi Facility HP','Pollution Control Consent to Operate','2026-06-01','HP/PCB/CTE/2022/778',
     '2022-11-01','2026-10-31',152,false,null,false,0,0.00,'pollution_consent','active_valid','stable',
     'Consent valid, next renewal cycle planned for Q4'),
    ('Noida Sector 63 Office','Shops & Establishments Registration','2026-07-01','UP/SE/2020/5567',
     '2025-05-01','2026-04-30',-63,false,null,false,0,8000.00,'shops_establishment','expired_lapsed','worsening',
     'Office relocation left registration address outdated, renewal missed'),
    ('Coimbatore Depot','Contract Labour License (Principal Employer)','2026-07-01','TN/CLRA/2019/3321',
     '2024-02-01','2026-01-31',-168,true,'2026-07-01',false,0,12000.00,'contract_labour_license','renewal_filed','improving',
     'Belated renewal filed after lapse, penalty paid, approval awaited'),
    ('Manesar Plant','Factory License - Section 6','2026-06-01','HR/FAC/2020/1188',
     '2024-01-01','2026-12-31',214,false,null,true,2,0.00,'factory_license','inspection_pending','stable',
     'Routine factory inspection scheduled, two minor findings open'),
    ('Ankleshwar Unit','Pollution Control Consent to Operate','2026-07-01','GJ/PCB/CTO/2021/990',
     '2023-09-01','2026-08-31',43,true,'2026-06-20',false,0,0.00,'pollution_consent','renewal_filed','improving',
     'CTO renewal filed with GPCB, site inspection cleared'),
    ('Bhiwadi Unit','Labour License - CLRA','2026-06-01','RJ/CLRA/2018/1743',
     '2023-05-01','2026-05-31',-31,false,null,true,4,30000.00,'labour_license','expired_lapsed','worsening',
     'Contractor headcount exceeded license limit, license lapsed on renewal'),
    ('Chennai Plant 1','Labour License - CLRA','2026-05-01','TN/CLRA/2022/9987',
     '2025-01-01','2026-12-31',275,false,null,false,0,0.00,'labour_license','active_valid','stable',
     'Well within validity, no renewal action due yet'),
    ('Pune Assembly Unit','Shops & Establishments Registration','2026-05-01','MH/SE/2023/1200',
     '2025-06-01','2026-05-31',15,false,null,true,1,0.00,'shops_establishment','renewal_overdue','worsening',
     'Facility admin staff turnover caused renewal filing delay')
  ) as q(site, ltype, pm, lnum, idate, edate, dte, rfiled, rfdate, idue, ifo, pen, lclass, rstatus, trd, nt);

  -- CAPA seed -- attach to specific rows via site_name + license_type
  insert into public.factory_license_capa_actions_r3731 (
    factory_license_id, root_cause, corrective_action,
    capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca,
    q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Pune Assembly Unit','Pollution Control Consent to Operate',
     'CTO renewal application not filed before 120-day statutory window',
     'File belated CTO renewal with SPCB and pay applicable late fee',
     'in_progress','EHS Manager','2026-08-30',null,
     'Belated application submitted; SPCB acknowledgement awaited'),
    ('Nashik Warehouse','Shops & Establishments Registration',
     'Facility admin missed renewal reminder in shared calendar',
     'Migrate all statutory renewal reminders to compliance tracker with 60-day alert',
     'closed','Compliance Lead','2026-07-15','2026-07-12',
     'Renewal filed and license reinstated, tracker now live for all sites'),
    ('Faridabad Unit 2','Factory License - Section 6',
     'HR site team unaware of 60-day advance filing requirement under Factories Act',
     'Assign dedicated factory-license renewal owner and file within 5 days',
     'open','Plant HR Head','2026-08-15',null,
     'Renewal application being prepared, inspector visit scheduled first'),
    ('Hosur Manufacturing Unit','Factory License - Section 6',
     'Chief Inspector of Factories flagged fire-safety NOC as expired during inspection',
     'Renew fire NOC and close all inspection findings before next audit',
     'overdue','Unit Safety Officer','2026-07-31',null,
     'Fire NOC renewal delayed by vendor; escalated to plant head'),
    ('Noida Sector 63 Office','Shops & Establishments Registration',
     'Office relocation within same city not updated in registration, renewal notice missed',
     'Update registered address and file renewal with applicable penalty',
     'in_progress','Admin Manager','2026-08-20',null,
     'Address correction filed with Labour Department, renewal pending approval'),
    ('Coimbatore Depot','Contract Labour License (Principal Employer)',
     'Principal employer license lapsed while contractor license renewal was in process, sequencing error',
     'Align principal employer and contractor license renewal calendars',
     'closed','Regional Compliance Officer','2026-07-05','2026-07-01',
     'Both licenses now renewed and calendars synced going forward'),
    ('Bhiwadi Unit','Labour License - CLRA',
     'Contractor headcount threshold crossed without license amendment, license lapsed on renewal',
     'File amended labour license reflecting current contractor headcount',
     'open','Site HR Manager','2026-08-25',null,
     'Penalty paid; amended license application under Labour Department review'),
    ('Pune Assembly Unit','Shops & Establishments Registration',
     'Renewal filing deadline missed due to change in facility admin staff',
     'Cross-train backup admin owner and set redundant reminder alerts',
     'in_progress','Facility Manager','2026-08-10',null,
     'Backup owner assigned; renewal filing in progress this week')
  ) as q(site, ltype, rc, ca, cst, ownr, tcd, acd, nt)
  join public.factory_license_r3731 e
    on e.organization_id = v_org_id and e.site_name = q.site and e.license_type = q.ltype;
end;
$seed$;

-- =============================================================================
-- RPCs -- 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal-status distribution
create or replace function public.founder_r3731_renewal_status_rollup()
returns table(renewal_status text, licenses bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.factory_license_r3731)
  select l.renewal_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.factory_license_r3731 l
  group by l.renewal_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3731_renewal_status_rollup() from public, anon;
grant execute on function public.founder_r3731_renewal_status_rollup() to authenticated;

-- 2) Site scorecard
create or replace function public.founder_r3731_site_scorecard()
returns table(
  site_name text,
  licenses bigint,
  active_valid bigint,
  renewal_overdue bigint,
  expired_lapsed bigint,
  inspection_pending bigint,
  open_inspection_findings bigint,
  total_penalty_rupees numeric,
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
    count(*) filter (where l.renewal_status = 'active_valid')::bigint,
    count(*) filter (where l.renewal_status = 'renewal_overdue')::bigint,
    count(*) filter (where l.renewal_status = 'expired_lapsed')::bigint,
    count(*) filter (where l.renewal_status = 'inspection_pending')::bigint,
    coalesce(sum(l.inspection_findings_open),0)::bigint,
    coalesce(sum(l.penalty_rupees),0)::numeric,
    round(avg(l.days_to_expiry), 1)
  from public.factory_license_r3731 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3731_site_scorecard() from public, anon;
grant execute on function public.founder_r3731_site_scorecard() to authenticated;

-- 3) License-class x renewal-status matrix
create or replace function public.founder_r3731_license_class_status_matrix()
returns table(license_class text, renewal_status text, licenses bigint, avg_days_to_expiry numeric, total_penalty_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.license_class, l.renewal_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1),
    coalesce(sum(l.penalty_rupees),0)::numeric
  from public.factory_license_r3731 l
  group by l.license_class, l.renewal_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3731_license_class_status_matrix() from public, anon;
grant execute on function public.founder_r3731_license_class_status_matrix() to authenticated;

-- 4) Monthly expiry trend
create or replace function public.founder_r3731_monthly_expiry_trend()
returns table(period_month date, licenses bigint, avg_days_to_expiry numeric, renewals_filed bigint, expired_count bigint, worsening_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.days_to_expiry), 1),
    count(*) filter (where l.renewal_filed = true)::bigint,
    count(*) filter (where l.renewal_status = 'expired_lapsed')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.factory_license_r3731 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3731_monthly_expiry_trend() from public, anon;
grant execute on function public.founder_r3731_monthly_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3731_capa_status_board()
returns table(capa_status text, findings bigint, closed_count bigint, overdue_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'closed')::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.factory_license_capa_actions_r3731 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3731_capa_status_board() from public, anon;
grant execute on function public.founder_r3731_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3731_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.factory_license_capa_actions_r3731)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.factory_license_capa_actions_r3731 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3731_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3731_root_cause_pareto() to authenticated;

-- 7) Expiry-risk digest (licenses at risk of lapsing without a filed renewal)
create or replace function public.founder_r3731_expiry_risk_digest()
returns table(
  site_name text,
  license_type text,
  license_class text,
  expiry_date date,
  days_to_expiry int,
  renewal_filed boolean,
  inspection_due boolean,
  renewal_status text,
  penalty_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.license_type, l.license_class, l.expiry_date, l.days_to_expiry,
    l.renewal_filed, l.inspection_due, l.renewal_status, l.penalty_rupees
  from public.factory_license_r3731 l
  where l.renewal_filed = false
    and (l.days_to_expiry <= 30 or l.renewal_status in ('renewal_overdue','expired_lapsed'))
  order by l.days_to_expiry asc;
end;
$$;

revoke all on function public.founder_r3731_expiry_risk_digest() from public, anon;
grant execute on function public.founder_r3731_expiry_risk_digest() to authenticated;

-- 8) High-risk renewal queue (overdue / lapsed licenses)
create or replace function public.founder_r3731_high_risk_queue()
returns table(
  site_name text,
  license_type text,
  license_class text,
  license_number text,
  expiry_date date,
  days_to_expiry int,
  renewal_status text,
  inspection_due boolean,
  inspection_findings_open int,
  penalty_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.license_type, l.license_class, l.license_number, l.expiry_date, l.days_to_expiry,
    l.renewal_status, l.inspection_due, l.inspection_findings_open, l.penalty_rupees, l.notes
  from public.factory_license_r3731 l
  where l.renewal_status in ('expired_lapsed','renewal_overdue')
  order by l.days_to_expiry asc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3731_high_risk_queue() from public, anon;
grant execute on function public.founder_r3731_high_risk_queue() to authenticated;
