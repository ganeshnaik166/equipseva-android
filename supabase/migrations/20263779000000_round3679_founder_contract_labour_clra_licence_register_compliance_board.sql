-- Round 3679: Contract-Labour (CLRA) Licence / Register Compliance Board
-- CLRA compliance — site × contractor × licence expiry × registers × wage compliance × PF/ESI remittance × inspections × CAPA

-- =============================================================================
-- TABLE 1: clra_r3679 — per-site per-contractor CLRA compliance records
-- =============================================================================
create table if not exists public.clra_r3679 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  contractor_name text not null,
  period_month date not null,
  clra_licence_no text not null,
  licence_expiry date,
  days_to_expiry int,
  contract_workers int not null,
  threshold_applicable boolean not null,
  registers_current_pct numeric(5,2),
  wage_compliance_pct numeric(5,2),
  pf_esi_remitted boolean not null,
  inspections_open int not null default 0,
  site_type text not null check (site_type in (
    'warehouse','office','workshop','customer_site_deployed','refurb_center'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','renewal_due','register_gap','wage_gap','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.clra_r3679 enable row level security;

create index if not exists idx_clra_r3679_org on public.clra_r3679(organization_id);
create index if not exists idx_clra_r3679_month on public.clra_r3679(period_month);
create index if not exists idx_clra_r3679_status on public.clra_r3679(compliance_status);

-- =============================================================================
-- TABLE 2: clra_capa_actions_r3679 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.clra_capa_actions_r3679 (
  id uuid primary key default gen_random_uuid(),
  clra_record_id uuid not null references public.clra_r3679(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'licence_renewal_missed','register_not_updated','wage_underpayment',
    'pf_esi_remittance_delay','contractor_paperwork_lapse','headcount_exceeded_licence',
    'principal_employer_oversight_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_licence_renewal','update_registers','recover_and_pay_wage_arrears',
    'remit_pf_esi_dues','amend_licence_headcount','replace_contractor',
    'train_site_hr','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  penalty_exposure_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.clra_capa_actions_r3679 enable row level security;

create index if not exists idx_clra_capa_r3679_record on public.clra_capa_actions_r3679(clra_record_id);
create index if not exists idx_clra_capa_r3679_status on public.clra_capa_actions_r3679(capa_status);

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

  -- 16 CLRA compliance rows
  insert into public.clra_r3679 (
    organization_id, site_name, contractor_name, period_month, clra_licence_no,
    licence_expiry, days_to_expiry, contract_workers, threshold_applicable,
    registers_current_pct, wage_compliance_pct, pf_esi_remitted, inspections_open,
    site_type, compliance_status, trend_dir, notes
  )
  select v_org_id, q.sname, q.cname, q.pm::date, q.lic,
    q.lexp::date, q.dte, q.cw, q.thr,
    q.regp, q.wagep, q.pfes, q.insp,
    q.styp, q.cst, q.tdir, q.nt
  from (values
    ('Mumbai HQ Office','SecureFacil Services','2026-07-01','CLRA/MH/2024/11821',
     '2027-03-31',234,42,true,100.0,99.2,true,0,'office','compliant','stable',
     'Housekeeping and security contract — all registers digital and current'),
    ('Mumbai HQ Office','CleanKart Facility Mgmt','2026-06-01','CLRA/MH/2023/09312',
     '2026-08-20',49,28,true,92.5,97.8,true,0,'office','renewal_due','stable',
     'Licence renewal window open — application drafted for MH labour dept portal'),
    ('Chennai Service Workshop','Sai Industrial Manpower','2026-07-01','CLRA/TN/2024/04455',
     '2027-01-15',159,55,true,88.0,96.4,true,1,'workshop','register_gap','improving',
     'Form XIII wage register two months behind — catch-up entry drive underway'),
    ('Chennai Service Workshop','Velan Engineering Staff','2026-06-01','CLRA/TN/2022/02218',
     '2026-07-10',-30,36,true,95.0,84.7,false,1,'workshop','non_compliant','worsening',
     'Licence lapsed and June PF remittance missed — contract work suspended'),
    ('Delhi NCR Warehouse','Bharat Logistics Labour Co','2026-07-01','CLRA/DL/2024/07733',
     '2026-12-05',118,64,true,97.5,90.1,true,2,'warehouse','wage_gap','worsening',
     'Overtime underpayment flagged in DL labour department inspection'),
    ('Delhi NCR Warehouse','Riddhi Warehousing Services','2026-06-01','CLRA/DL/2023/05120',
     '2027-02-28',203,48,true,99.0,99.5,true,0,'warehouse','compliant','improving',
     'Post-CAPA re-audit clean — registers and wage payments verified'),
    ('Bengaluru Refurb Center','Kaveri Technical Manpower','2026-07-01','CLRA/KA/2024/06611',
     '2026-09-14',36,58,true,90.5,98.2,true,0,'refurb_center','renewal_due','stable',
     'Renewal due within 45 days — KA labour dept portal filing started'),
    ('Bengaluru Refurb Center','Nandi Facility Services','2026-06-01','CLRA/KA/2023/03980',
     '2027-04-30',264,22,true,100.0,100.0,true,0,'refurb_center','compliant','stable',
     'Canteen and housekeeping contract fully compliant'),
    ('Apollo Chennai Deployed Site','MedServe Site Crew','2026-07-01','CLRA/TN/2024/08822',
     '2026-11-30',113,18,false,85.0,95.5,true,0,'customer_site_deployed','register_gap','stable',
     'Below 20-worker threshold but registers maintained voluntarily — muster roll gap'),
    ('Kokilaben Mumbai Deployed Site','MedServe Site Crew West','2026-06-01','CLRA/MH/2024/10105',
     '2027-01-22',166,26,true,96.0,88.9,false,1,'customer_site_deployed','wage_gap','improving',
     'ESI remittance delayed 12 days — arrears computation shared with contractor'),
    ('Chennai Spares Depot','Amman Loading Services','2026-07-01','CLRA/TN/2023/06767',
     '2026-10-18',70,31,true,93.5,97.0,true,0,'warehouse','register_gap','improving',
     'Form XXIV half-yearly return filed late — register backfill in progress'),
    ('Delhi Service Office','Capital Facility Crew','2026-06-01','CLRA/DL/2022/03341',
     '2026-08-05',-4,19,false,98.0,99.0,true,0,'office','renewal_due','worsening',
     'Licence expired this week — renewal filed, acknowledgement awaited'),
    ('Bengaluru Refurb Center','Hoysala Industrial Services','2026-07-01','CLRA/KA/2024/09214',
     '2027-06-30',325,44,true,99.5,99.8,true,0,'refurb_center','compliant','stable',
     'Refurb line contract — wage parity audit clean'),
    ('AIIMS Delhi Deployed Site','MedServe Site Crew North','2026-07-01','CLRA/DL/2024/11209',
     '2026-12-22',135,21,true,82.0,79.5,false,2,'customer_site_deployed','non_compliant','worsening',
     'Wage register and PF both in arrears — contractor show-cause issued'),
    ('Mumbai Port Warehouse','Konkan Cargo Manpower','2026-06-01','CLRA/MH/2023/07854',
     '2027-03-12',215,52,true,94.0,98.6,true,0,'warehouse','compliant','improving',
     'Port warehouse handling crew — registers current after June drive'),
    ('Chennai Service Workshop','Sai Industrial Manpower South','2026-06-01','CLRA/TN/2024/05590',
     '2026-09-02',24,40,true,89.0,92.3,true,1,'workshop','wage_gap','stable',
     'Minimum-wage revision not applied for April-May — arrears being computed')
  ) as q(sname, cname, pm, lic, lexp, dte, cw, thr, regp, wagep, pfes, insp, styp, cst, tdir, nt);

  -- CAPA seed — attach to specific records via clra_licence_no
  insert into public.clra_capa_actions_r3679 (
    clra_record_id, root_cause, corrective_action, capa_status,
    penalty_exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.pen, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CLRA/TN/2022/02218','licence_renewal_missed','file_licence_renewal','escalated',
     250000.00,'Ravi Subramanian','2026-07-15',null,
     'Lapsed licence — work suspended till fresh licence; Sec 23 penalty exposure'),
    ('CLRA/DL/2024/07733','wage_underpayment','recover_and_pay_wage_arrears','in_progress',
     180000.00,'Meena Kapoor','2026-08-25',null,
     'OT arrears for 14 workers being disbursed with next wage cycle'),
    ('CLRA/TN/2024/04455','register_not_updated','update_registers','verification_pending',
     40000.00,'Karthik Iyer','2026-08-10',null,
     'Form XIII backfilled — awaiting site HR verification'),
    ('CLRA/MH/2024/10105','pf_esi_remittance_delay','remit_pf_esi_dues','closed',
     36000.00,'Sneha Patil','2026-07-20','2026-07-18',
     'ESI dues remitted with interest; challan filed and CAPA verified'),
    ('CLRA/DL/2024/11209','pf_esi_remittance_delay','replace_contractor','open',
     320000.00,'Amit Verma','2026-09-05',null,
     'Repeat PF default — replacement contractor shortlisting started'),
    ('CLRA/KA/2024/06611','contractor_paperwork_lapse','file_licence_renewal','in_progress',
     15000.00,'Divya Rao','2026-08-30',null,
     'Renewal filing on KA portal — awaiting contractor Form V'),
    ('CLRA/TN/2024/05590','wage_underpayment','recover_and_pay_wage_arrears','overdue',
     95000.00,'Karthik Iyer','2026-07-31',null,
     'Minimum-wage revision arrears past target — escalated to contractor MD'),
    ('CLRA/TN/2024/08822','register_not_updated','train_site_hr','open',
     12000.00,'Priya Nair','2026-08-20',null,
     'Muster roll gaps at deployed site — HR refresher session scheduled')
  ) as q(lic, rc, ca, cst, pen, own, tcd, acd, nt)
  join public.clra_r3679 e
    on e.organization_id = v_org_id and e.clra_licence_no = q.lic;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3679_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clra_r3679)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.clra_r3679 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3679_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3679_compliance_status_rollup() to authenticated;

-- 2) Contractor compliance scorecard
create or replace function public.founder_r3679_contractor_scorecard()
returns table(
  contractor_name text,
  total_records bigint,
  compliant bigint,
  renewal_due bigint,
  register_gap bigint,
  wage_gap bigint,
  non_compliant bigint,
  total_workers bigint,
  avg_wage_compliance_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contractor_name,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'register_gap')::bigint,
    count(*) filter (where l.compliance_status = 'wage_gap')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    coalesce(sum(l.contract_workers),0)::bigint,
    round(avg(l.wage_compliance_pct), 1),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.clra_r3679 l
  group by l.contractor_name
  order by count(*) desc, l.contractor_name;
end;
$$;

revoke all on function public.founder_r3679_contractor_scorecard() from public, anon;
grant execute on function public.founder_r3679_contractor_scorecard() to authenticated;

-- 3) Site-type × compliance-status matrix
create or replace function public.founder_r3679_site_type_status_matrix()
returns table(site_type text, compliance_status text, records bigint, total_workers bigint, avg_registers_current_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_type, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.contract_workers),0)::bigint,
    round(avg(l.registers_current_pct), 1)
  from public.clra_r3679 l
  group by l.site_type, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3679_site_type_status_matrix() from public, anon;
grant execute on function public.founder_r3679_site_type_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3679_monthly_compliance_trend()
returns table(period_month date, records bigint, compliant bigint, non_compliant bigint, avg_registers_current_pct numeric, avg_wage_compliance_pct numeric, pf_esi_pending bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    round(avg(l.registers_current_pct), 1),
    round(avg(l.wage_compliance_pct), 1),
    count(*) filter (where l.pf_esi_remitted = false)::bigint
  from public.clra_r3679 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3679_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3679_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3679_capa_status_board()
returns table(capa_status text, actions bigint, avg_penalty_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.penalty_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.clra_capa_actions_r3679 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3679_capa_status_board() from public, anon;
grant execute on function public.founder_r3679_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3679_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clra_capa_actions_r3679)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.penalty_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.clra_capa_actions_r3679 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3679_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3679_root_cause_pareto() to authenticated;

-- 7) Wage / register gap digest
create or replace function public.founder_r3679_wage_register_gap_digest()
returns table(
  contractor_name text,
  gap_records bigint,
  register_gap_records bigint,
  wage_gap_records bigint,
  avg_registers_current_pct numeric,
  avg_wage_compliance_pct numeric,
  pf_esi_pending bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contractor_name,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'register_gap')::bigint,
    count(*) filter (where l.compliance_status = 'wage_gap')::bigint,
    round(avg(l.registers_current_pct), 1),
    round(avg(l.wage_compliance_pct), 1),
    count(*) filter (where l.pf_esi_remitted = false)::bigint
  from public.clra_r3679 l
  where l.compliance_status in ('register_gap','wage_gap','non_compliant')
     or l.pf_esi_remitted = false
     or l.registers_current_pct < 100
     or l.wage_compliance_pct < 100
  group by l.contractor_name
  order by count(*) desc, l.contractor_name;
end;
$$;

revoke all on function public.founder_r3679_wage_register_gap_digest() from public, anon;
grant execute on function public.founder_r3679_wage_register_gap_digest() to authenticated;

-- 8) High-risk compliance queue
create or replace function public.founder_r3679_high_risk_queue()
returns table(
  site_name text,
  contractor_name text,
  period_month date,
  clra_licence_no text,
  licence_expiry date,
  days_to_expiry int,
  contract_workers int,
  compliance_status text,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.contractor_name, l.period_month, l.clra_licence_no,
    l.licence_expiry, l.days_to_expiry, l.contract_workers,
    l.compliance_status, l.trend_dir, l.notes
  from public.clra_r3679 l
  where l.compliance_status in ('non_compliant','wage_gap')
     or l.pf_esi_remitted = false
     or l.days_to_expiry <= 45
     or l.inspections_open > 0
  order by l.period_month desc, l.site_name;
end;
$$;

revoke all on function public.founder_r3679_high_risk_queue() from public, anon;
grant execute on function public.founder_r3679_high_risk_queue() to authenticated;
